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
            address(0x24a42fD28C976A61Df5D00D0599C34c4f90748c8)
        ); // mainnet address
    LendingPool lendingPool = LendingPool(provider.getLendingPool());

    constructor() {
        owner = msg.sender; // sets contract owner
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    function depositERC20(
        address _reserve,
        uint256 _amount,
        uint16 _referralCode
    ) external {
        uint256 contractBalance = IERC20(_reserve).balanceOf(address(this));
        console.log(contractBalance);
        IERC20(_reserve).approve(provider.getLendingPoolCore(), _amount);

        lendingPool.deposit(_reserve, _amount, address(this), _referralCode);
        contractBalance = IERC20(_reserve).balanceOf(address(this));
        console.log(contractBalance);
    }

    function withdrawERC20(
        address _reserve,
        uint256 _amount,
        address _withdrawToken
    ) external {
        uint256 contractBalance = IERC20(_reserve).balanceOf(address(this));
        if (contractBalance >= _amount) {
            lendingPool.withdraw(_withdrawToken, _amount, address(this));
            contractBalance = IERC20(_withdrawToken).balanceOf(address(this));
            console.log(contractBalance);
            IERC20(_withdrawToken).transfer(owner, _amount);
        } else {
            console.log("Not enough Balance");
        }
    }

    function borrowERC20(
        address _reserve,
        uint256 _amount,
        uint256 _interestRateMode,
        uint16 _referralCode,
        address _collateral
    ) external {
        lendingPool.setUserUseReserveAsCollateral(_collateral, true);

        lendingPool.borrow(
            _reserve,
            _amount,
            _interestRateMode,
            _referralCode,
            address(this)
        );
        IERC20(_reserve).transfer(owner, _amount);
    }

    function repayERC20(
        address _reserve,
        uint256 _amount,
        uint256 _rateMode
    ) external returns (uint256) {
        address contractAddress = address(this);
        IERC20(_reserve).approve(provider.getLendingPoolCore(), _amount);

        return lendingPool.repay(_reserve, _amount, _rateMode, contractAddress);
    }

    function depositEth(uint16 _referralCode) external payable {
        address _reserve = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        lendingPool.deposit{value: msg.value}(
            _reserve,
            msg.value,
            address(this),
            _referralCode
        );
        address aEth = address(0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04);
        uint256 contractBalance = IERC20(aEth).balanceOf(address(this));
        console.log(contractBalance);
    }

    function withdrawEth(address _aEth, uint256 _amount) external {
        uint256 contractBalance = IERC20(_aEth).balanceOf(address(this));
        if (contractBalance >= _amount) {
            address Eth = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
            uint256 redeemResult = lendingPool.withdraw(
                Eth,
                _amount,
                address(this)
            );
            console.log(redeemResult);
            (bool success, ) = owner.call{value: address(this).balance}("");
            require(success, "FAILURE, ETHER NOT SENT");
        }
    }

    function borrowEth(
        uint256 _amount,
        uint256 _interestRateMode,
        uint16 _referralCode,
        address _collateral
    ) external {
        lendingPool.setUserUseReserveAsCollateral(_collateral, true);
        address Eth = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        lendingPool.borrow(
            Eth,
            _amount,
            _interestRateMode,
            _referralCode,
            address(this)
        );
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "FAILURE, ETHER NOT SENT");
    }

    function repayEth(uint256 _amount, uint256 _rateMode) external payable {
        address contractAddress = address(this);
        address Eth = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        lendingPool.repay(Eth, _amount, _rateMode, contractAddress);
        console.log(address(this).balance);
    }
}
