// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "./interfaces/Aave.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AaveMiddleContract {
    address private owner;

    LendingPoolAddressesProvider provider =
        LendingPoolAddressesProvider(
            address(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5)
        ); // mainnet address
    WETHGateway weth =  WETHGateway(address(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5));
    LendingPool lendingPool;

    constructor() {
        owner = msg.sender; // sets contract owner
        lendingPool = LendingPool(provider.getLendingPool());
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

        IERC20(_reserve).transferFrom(msg.sender,address(this), _amount);

        uint256 contractBalance = IERC20(_reserve).balanceOf(address(this));
        console.log(contractBalance);
        IERC20(_reserve).approve(provider.getLendingPoolCore(), _amount);

        lendingPool.deposit(_reserve, _amount, address(this), _referralCode);
        uint256 newContractBalance = IERC20(_reserve).balanceOf(address(this));
        require((newContractBalance - contractBalance ) != _amount ,"TOKEN DEPOSIT FAILED" );
    }

    function withdrawERC20(
        address _reserve,
        uint256 _amount,
        address _withdrawToken
    ) external _ownerOnly {
        uint256 contractBalance = IERC20(_reserve).balanceOf(address(this));
        require(contractBalance < _amount, "NOT ENOUGH aTOKENS");
        uint256 redeemResult = lendingPool.withdraw(
            _withdrawToken,
            _amount,
            address(this)
        );
        contractBalance = IERC20(_withdrawToken).balanceOf(address(this));
        console.log(contractBalance);
        require(redeemResult == 0, "ERROR WHILE REDEEMING");
        IERC20(_withdrawToken).transfer(owner, _amount);
    }

    function borrowERC20(
        address _reserve,
        uint256 _amount,
        uint256 _interestRateMode,
        uint16 _referralCode,
        address _collateral
    ) external _ownerOnly {
        uint256 contractBalance = IERC20(_reserve).balanceOf(address(this));
        lendingPool.setUserUseReserveAsCollateral(_collateral, true);

        lendingPool.borrow(
            _reserve,
            _amount,
            _interestRateMode,
            _referralCode,
            address(this)
        );
        uint256 newContractBalance = IERC20(_reserve).balanceOf(address(this));
        require((newContractBalance - contractBalance) == 0, "BORROW FAILED");
        IERC20(_reserve).transfer(owner, _amount);
    }

    function repayERC20(
        address _reserve,
        uint256 _amount,
        uint256 _rateMode
    ) external _ownerOnly  {
        address contractAddress = address(this);

        IERC20(_reserve).transferFrom(msg.sender,address(this), _amount);

        IERC20(_reserve).approve(provider.getLendingPoolCore(), _amount);

        uint256 repayAmount = lendingPool.repay(_reserve, _amount, _rateMode, contractAddress);
        require(repayAmount == 0, "REPAY FAILED");
    }

    function depositEth(uint16 _referralCode) external payable _ownerOnly {
        address _reserve = address(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
        uint256 contractBalance = IERC20(aWEth).balanceOf(address(this));
        weth.depositETH{value: msg.value}(
            _reserve,
            address(this),
            _referralCode
        );
        address aWEth = address(0x030bA81f1c18d280636F32af80b9AAd02Cf0854e);
        uint256 newContractBalance = IERC20(aWEth).balanceOf(address(this));
        require((newContractBalance - contractBalance) != msg.value, "DEPOSIT FAILED");
        console.log(contractBalance);
    }

    function withdrawEth(address _aWEth, uint256 _amount) external _ownerOnly {
        uint256 contractBalance = IERC20(_aWEth).balanceOf(address(this));

        require(contractBalance < _amount, "NOT ENOUGH aTOKENS");

        address _reserve = address(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
       weth.withdrawETH(
            _reserve,
            _amount,
            address(this)
        );
        
        uint256 newContractBalance = IERC20(_aWEth).balanceOf(address(this));
        requir( (contractBalance - newContractBalance) !=_amount,"WITHDRAW FAILED");
        (bool success, ) = owner.call{value: address(this).balance}("");

        require(success, "FAILURE IN SENDING ETHER TO USER");
    }

    function borrowEth(
        uint256 _amount,
        uint256 _interestRateMode,
        uint16 _referralCode,
        address _collateral
    ) external _ownerOnly {
        require(
            IERC20(_collateral).balanceOf(address(this)) > 0,
            "DEPOSIT TOKENS FIRST"
        );

        lendingPool.setUserUseReserveAsCollateral(_collateral, true);

        address _reserve = address(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
        weth.borrowETH(
            _reserve,
            _amount,
            _interestRateMode,
            _referralCode
        );
        uint256 contractBalance = address(this).balance;
        require(contractBalance == 0 , "BORROW FAILED");
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "FAILURE, ETHER NOT SENT");
    }

    function repayEth(uint256 _rateMode) external payable _ownerOnly {
        address contractAddress = address(this);
        address _reserve = address(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
        uint256 totalBorrowsETH;
        (, , totalBorrowsETH, , , , , ) = lendingPool.getUserAccountData(
            address(this)
        );

        require(
            msg.value <= totalBorrowsETH,
            "REPAY AMOUNT MORE THAN BORROWED AMOUNT"
        );
        weth.repayETH{value: msg.value}(_reserve, msg.value, _rateMode, contractAddress);
        console.log(address(this).balance);
    }
}

}
