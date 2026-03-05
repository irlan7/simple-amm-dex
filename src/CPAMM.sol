// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CPAMM {
    using SafeERC20 for IERC20;

    IERC20 public immutable TOKEN0;
    IERC20 public immutable TOKEN1;

    uint public reserve0;
    uint public reserve1;
    uint public totalSupply;
    mapping(address => uint) public balanceOf;

    constructor(address _token0, address _token1) {
        TOKEN0 = IERC20(_token0);
        TOKEN1 = IERC20(_token1);
    }

    function _mint(address _to, uint _amount) private {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
    }

    function _burn(address _from, uint _amount) private {
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    function _update(uint _reserve0, uint _reserve1) private {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    function swap(address _tokenIn, uint _amountIn) external returns (uint amountOut) {
        require(_tokenIn == address(TOKEN0) || _tokenIn == address(TOKEN1), "invalid token");
        require(_amountIn > 0, "amount in = 0");

        bool isToken0 = _tokenIn == address(TOKEN0);
        (IERC20 tokenIn, IERC20 tokenOut, uint reserveIn, uint reserveOut) = isToken0
            ? (TOKEN0, TOKEN1, reserve0, reserve1)
            : (TOKEN1, TOKEN0, reserve1, reserve0);

        // Security Update: Using safeTransferFrom
        tokenIn.safeTransferFrom(msg.sender, address(this), _amountIn);

        uint amountInWithFee = (_amountIn * 997) / 1000;
        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);

        // Security Update: Using safeTransfer
        tokenOut.safeTransfer(msg.sender, amountOut);
        _update(TOKEN0.balanceOf(address(this)), TOKEN1.balanceOf(address(this)));
    }

    function addLiquidity(uint _amount0, uint _amount1) external returns (uint shares) {
        // Security Update: Using safeTransferFrom
        TOKEN0.safeTransferFrom(msg.sender, address(this), _amount0);
        TOKEN1.safeTransferFrom(msg.sender, address(this), _amount1);

        if (reserve0 > 0 || reserve1 > 0) {
            require(reserve0 * _amount1 == reserve1 * _amount0, "x/y != dx/dy");
        }

        if (totalSupply == 0) {
            shares = _sqrt(_amount0 * _amount1);
        } else {
            shares = _min((_amount0 * totalSupply) / reserve0, (_amount1 * totalSupply) / reserve1);
        }
        require(shares > 0, "shares = 0");
        _mint(msg.sender, shares);
        _update(TOKEN0.balanceOf(address(this)), TOKEN1.balanceOf(address(this)));
    }

    function removeLiquidity(uint _shares) external returns (uint amount0, uint amount1) {
        uint bal0 = TOKEN0.balanceOf(address(this));
        uint bal1 = TOKEN1.balanceOf(address(this));

        amount0 = (_shares * bal0) / totalSupply;
        amount1 = (_shares * bal1) / totalSupply;
        require(amount0 > 0 && amount1 > 0, "amount0 or amount1 = 0");

        _burn(msg.sender, _shares);
        _update(bal0 - amount0, bal1 - amount1);

        // Security Update: Using safeTransfer
        TOKEN0.safeTransfer(msg.sender, amount0);
        TOKEN1.safeTransfer(msg.sender, amount1);
    }

    function _sqrt(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }
}
