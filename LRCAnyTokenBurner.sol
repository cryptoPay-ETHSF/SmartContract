
pragma solidity 0.4.24;

// @author Sowmay Jain, Satish Nampally & Samyak Jain

interface token {
    function balanceOf(address who) external returns(uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function burn(uint _value) external returns (bool);
}

interface Kyber {
    function trade(
        address src,
        uint srcAmount,
        address dest,
        address destAddress,
        uint maxDestAmount,
        uint minConversionRate,
        address walletId
    ) external payable returns (uint);
}

contract MockBurnManager {

    address public lrcAddress = 0xDb0040451F373949A4Be60dcd7b6B8D6E42658B6; // It's BAT token contract which is used for demontration purpose instead of LRC
    address public KyberDEX = 0x818E6FECD516Ecc3849DAf6845e3EC868087B755; // KN Proxy

    // Only 2 tokens yet supported to demonstarte Any Token conversion to LRC
    function ApproveERC20() internal {
        token OMGtkn = token(0x4BFBa4a8F28755Cb2061c413459EE562c6B9c51b);
        OMGtkn.approve(KyberDEX, 2**256 - 1);
        token KNCtkn = token(0x4E470dc7321E84CA96FcAEDD0C8aBCebbAEB68C6);
        KNCtkn.approve(KyberDEX, 2**256 - 1);
    }

    constructor() public {
        ApproveERC20();
    }

    // Quick Explanation
    // - This MockBurnManager contract demonstrates burning LRC token even if the fees are collected in any other ERC20 tokens.
    // - It's completely decentralized and works onchain integrated with Kyber Network to convert any token into LRC. 
    // - For now, we are converting (KNC, OMG) to and burning (BAT) for demonstration purpose as LRC is not listed on Kyber.

    // Further Improvements
    // - Check prices from many other protocols like Bancor etc to get the best price and burn as much LRC as possible
    // - Make a grouped allowance and conversion of many tokens at once by calling one Tx
    // - Automatically read the balance quantity of token to burn from the related ERC20 token contract

    function burnLRC(
        address tokenToBurn,
        uint qtyToBurn // value in decimals
        )
        external
        returns (bool)
    {
        // We had started supporting burning tokens other than LRC ;)
        if (tokenToBurn != lrcAddress) {

            // converting other token (KNC, OMG) into BAT using Kyber Network protocol
            Kyber kyberFunctions = Kyber(KyberDEX);
            uint QtyTknToBurn = kyberFunctions.trade.value(0)(
                tokenToBurn, // selling token
                qtyToBurn, // selling token amount
                lrcAddress, // buy token
                address(this), // address(this)
                2**256 - 1,
                0,
                0
            );

            // call the burn function from the ERC20 token
            token LRCtkn = token(lrcAddress);
            LRCtkn.burn(QtyTknToBurn);

            return true;
        }

    }

}