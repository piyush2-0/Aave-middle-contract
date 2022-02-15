// contracts/MyContract.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "hardhat/console.sol";
import "./interfaces/Aave.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract AaveMiddleContract is Initializable {
    address private owner;
    uint256 private ethBorrowBalance;
    bool private initialized;

    LendingPoolAddressesProvider provider;
    WETHGateway weth;
    LendingPool lendingPool;

    function initialize() public initializer {
        require(!initialized, "Contract instance has already been initialized");
        initialized = true;
        owner = msg.sender; // sets contract owner
        provider = LendingPoolAddressesProvider(
            address(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5)
        ); // mainnet address
        lendingPool = LendingPool(
            address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9)
        );
        weth = WETHGateway(address(0xcc9a0B7c43DC2a5F023Bb9b738E45B0Ef6B06E04));
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    modifier _ownerOnly() {
        require(msg.sender == owner);
        _;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    function depositERC20(
        address _reserve,
        uint256 _amount,
        uint16 _referralCode
    ) external _ownerOnly {
        IERC20Upgradeable token = IERC20Upgradeable(_reserve);
        token.transferFrom(msg.sender, address(this), _amount);

        uint256 contractBalance = token.balanceOf(address(this));
        console.log(contractBalance);
        token.approve(
            address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9),
            _amount
        );

        lendingPool.deposit(_reserve, _amount, address(this), _referralCode);
        uint256 newContractBalance = token.balanceOf(address(this));
        console.log(newContractBalance);
        require(
            (contractBalance - newContractBalance) == _amount,
            "TOKEN DEPOSIT FAILED"
        );
    }

    function withdrawERC20(
        address _reserve,
        uint256 _amount,
        address _withdrawToken
    ) external _ownerOnly {
        uint256 contractBalance = IERC20Upgradeable(_withdrawToken).balanceOf(
            address(this)
        );
        require(contractBalance >= _amount, "NOT ENOUGH aTOKENS");
        uint256 redeemResult = lendingPool.withdraw(
            _reserve,
            _amount,
            address(this)
        );
        contractBalance = IERC20Upgradeable(_withdrawToken).balanceOf(
            address(this)
        );
        console.log(contractBalance);
        require(redeemResult != 0, "ERROR WHILE REDEEMING");
        IERC20Upgradeable(_reserve).transfer(owner, _amount);
    }

    function borrowERC20(
        address _reserve,
        uint256 _amount,
        uint256 _interestRateMode,
        uint16 _referralCode
    ) external _ownerOnly {
        address aWEth = address(0x030bA81f1c18d280636F32af80b9AAd02Cf0854e);
        require(
            IERC20Upgradeable(aWEth).balanceOf(address(this)) > 0,
            "DEPOSIT ETHER FIRST"
        );

        uint256 contractBalance = IERC20Upgradeable(_reserve).balanceOf(
            address(this)
        );
        PriceOracle price = PriceOracle(provider.getPriceOracle());
        uint256 amountInEth = _amount * price.getAssetPrice(_reserve);
        console.log(amountInEth);
        uint256 availableBorrowsETH;

        (, , availableBorrowsETH, , , ) = lendingPool.getUserAccountData(
            address(this)
        );
        console.log(availableBorrowsETH);
        require(
            amountInEth <= availableBorrowsETH,
            "BORROW FAILED: NOT ENOUGH COLLATERAL"
        );

        lendingPool.borrow(
            _reserve,
            _amount,
            _interestRateMode,
            _referralCode,
            address(this)
        );
        uint256 newContractBalance = IERC20Upgradeable(_reserve).balanceOf(
            address(this)
        );
        require((newContractBalance - contractBalance) != 0, "BORROW FAILED");
        IERC20Upgradeable(_reserve).transfer(owner, _amount);
    }

    function repayERC20(
        address _reserve,
        uint256 _amount,
        uint256 _rateMode
    ) external _ownerOnly {
        address contractAddress = address(this);

        AaveProtocolDataProvider token = AaveProtocolDataProvider(
            address(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d)
        );
        uint256 currentStableDebt;
        (, currentStableDebt, , , , , , , ) = token.getUserReserveData(
            _reserve,
            address(this)
        );
        require(
            _amount <= currentStableDebt,
            "REPAY AMOUNT MORE THAN BORROWED AMOUNT"
        );

        // ERC20 tk = ERC20(_reserve);
        IERC20Upgradeable tk = IERC20Upgradeable(_reserve);
        IERC20Upgradeable(_reserve).transferFrom(
            msg.sender,
            address(this),
            _amount
        );

        tk.approve(
            address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9),
            _amount
        );

        uint256 repayAmount = lendingPool.repay(
            _reserve,
            _amount,
            _rateMode,
            contractAddress
        );
        require(repayAmount != 0, "REPAY FAILED");
    }

    function depositEth(uint16 _referralCode) external payable _ownerOnly {
        address _reserve = address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
        address aWEth = address(0x030bA81f1c18d280636F32af80b9AAd02Cf0854e);
        uint256 contractBalance = IERC20Upgradeable(aWEth).balanceOf(
            address(this)
        );
        weth.depositETH{value: msg.value}(
            _reserve,
            address(this),
            _referralCode
        );
        uint256 newContractBalance = IERC20Upgradeable(aWEth).balanceOf(
            address(this)
        );
        console.log(contractBalance);
        console.log(newContractBalance);
    }

    function withdrawEth(uint256 _amount) external _ownerOnly {
        address aWEth = address(0x030bA81f1c18d280636F32af80b9AAd02Cf0854e);
        IERC20Upgradeable token = IERC20Upgradeable(aWEth);
        uint256 contractBalance = IERC20Upgradeable(aWEth).balanceOf(
            address(this)
        );
        // ERC20 tk = ERC20(aWEth);
        console.log(contractBalance);
        require(contractBalance >= _amount, "NOT ENOUGH aTOKENS");
        token.approve(
            address(0xcc9a0B7c43DC2a5F023Bb9b738E45B0Ef6B06E04),
            _amount
        );
        address _reserve = address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
        weth.withdrawETH(_reserve, _amount, address(this));
        uint256 newcontractBalance = IERC20Upgradeable(aWEth).balanceOf(
            address(this)
        );
        console.log(newcontractBalance);
        require(address(this).balance > 0, "WITHDRAW FAILED");
        (bool success, ) = owner.call{value: address(this).balance}("");

        require(success, "FAILURE IN SENDING ETHER TO USER");
    }

    function borrowEth(
        uint256 _amount,
        uint256 _interestRateMode,
        uint16 _referralCode,
        address _collateral,
        address _deposited
    ) external _ownerOnly {
        require(
            IERC20Upgradeable(_collateral).balanceOf(address(this)) > 0,
            "DEPOSIT TOKENS FIRST"
        );
        //console.log(IERC20(_collateral).balanceOf(address(this)));

        lendingPool.setUserUseReserveAsCollateral(_deposited, true);

        address _reserve = address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
        AaveProtocolDataProvider pr = AaveProtocolDataProvider(
            address(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d)
        );

        // Get the relevant debt token address
        (, address stableDebtTokenAddress, ) = pr.getReserveTokensAddresses(
            address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
        );

        IStableDebtToken(stableDebtTokenAddress).approveDelegation(
            address(0xcc9a0B7c43DC2a5F023Bb9b738E45B0Ef6B06E04),
            _amount
        );

        uint256 availableBorrowsETH;

        (, , availableBorrowsETH, , , ) = lendingPool.getUserAccountData(
            address(this)
        );

        console.log(_amount);
        console.log(availableBorrowsETH);
        require(
            _amount <= availableBorrowsETH,
            "BORROW FAILED: NOT ENOUGH COLLATERAL"
        );
        weth.borrowETH(_reserve, _amount, _interestRateMode, _referralCode);
        uint256 contractBalance = address(this).balance;
        console.log(contractBalance);
        require(contractBalance != 0, "BORROW FAILED");
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "FAILURE, ETHER NOT SENT");
    }

    function getEthBorrowBalance() external view returns (uint256) {
        return ethBorrowBalance;
    }

    function repayEth(uint256 _rateMode) external payable _ownerOnly {
        address contractAddress = address(this);
        uint256 totalBorrowsETH;
        (, , totalBorrowsETH, , , ) = lendingPool.getUserAccountData(
            address(this)
        );

        require(
            msg.value <= totalBorrowsETH,
            "REPAY AMOUNT MORE THAN BORROWED AMOUNT"
        );

        address _reserve = address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
        weth.repayETH{value: msg.value}(
            _reserve,
            msg.value,
            _rateMode,
            contractAddress
        );
        console.log(address(this).balance);
    }
}
