
pragma solidity 0.4.24;

/// @author Sowmay Jain, Satish Nampally & Samyak Jain

interface token {
    function transfer(address receiver, uint amount) external returns(bool);
    function balanceOf(address who) external returns(uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint amt) external returns (bool);
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

// Interface for functions of MakerDAO CDP
interface MakerCDP {
    function open() external returns (bytes32 cup);
    function join(uint wad) external; // Join PETH
    function exit(uint wad) external; // Exit PETH
    function give(bytes32 cup, address guy) external;
    function lock(bytes32 cup, uint wad) external;
    function free(bytes32 cup, uint wad) external;
    function draw(bytes32 cup, uint wad) external;
    function wipe(bytes32 cup, uint wad) external;
    function shut(bytes32 cup) external;
    function bite(bytes32 cup) external;
}

// Interface retrives the ETH prices from MakerDAO price feeds
interface PriceInterface {
    function peek() public view returns (bytes32, bool);
}

interface WETHFace {
    function deposit() external payable;
    function withdraw(uint wad) external;
}

contract GlobalVar {
    mapping(address => uint) public AllSoldAmt;
    mapping(address => uint) public AllSoldTx;

    // not usable until the MelonPort guys add DAI as a token on Kovan Kyber Network
    address public ETHToken = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee;
    address public KyberAddress = 0x7e6b8b9510D71BF8EF0f893902EbB9C865eEF4Df; // KN Proxy on Kovan
    address public DAIToken = 0xC4375B7De8af5a38a93548eb8453a498222C4fF2; // DAI

    address public WETH = 0xd0a1e359811322d97991e03f863a0c30c2cf029c;
    address public PETH = 0xf4d791139ce033ad35db2b2201435fad668b1b64;
    address public MKR = 0xaaf64bfcc32d0f15873a02163e7e500671a4ffcd;
    address public DAI = 0xc4375b7de8af5a38a93548eb8453a498222c4ff2;

    address public onChainPrice = 0xA944bd4b25C9F186A846fd5668941AA3d3B8425F;

    address public CDPAddr = 0xa71937147b55Deb8a530C7229C442Fd3F31b7db2;
    MakerCDP DAILoanMaster = MakerCDP(CDPAddr);

    mapping (address => bytes32) public BorrowerCDP; // borrower >>> CDP Bytes
}

contract LoanPay is GlobalVar {

    function openCDP() internal returns (bytes32) {
        return DAILoanMaster.open();
    }

    // ETH to WETH
    function ETH_WETH(uint weiAmt) internal {
        WETHFace wethFunction = WETHFace(WETH);
        wethFunction.deposit.value(weiAmt)();
    }

    // WETH to PETH
    // WETH to PETH conversion will not be always same = give more WETH and get less PETH
    function WETH_PETH(uint weiAmt) internal {
        // factor the conversion rate between PETH & WETH
        DAILoanMaster.join(weiAmt);
    }

    // Lock PETH in CDP Contract
    function PETH_CDP(uint weiAmt) internal {
        DAILoanMaster.lock(BorrowerCDP[msg.sender], weiAmt);
    }

    // allowing WETH, PETH, MKR, DAI // called in the constructor
    function ApproveERC20() internal {
        token WETHtkn = token(WETH);
        WETHtkn.approve(CDPAddr, 2**256 - 1);
        token PETHtkn = token(PETH);
        PETHtkn.approve(CDPAddr, 2**256 - 1);
        token MKRtkn = token(MKR);
        MKRtkn.approve(CDPAddr, 2**256 - 1);
        token DAItkn = token(DAI);
        DAItkn.approve(CDPAddr, 2**256 - 1);
    }

}

// #1 Cases - Pay in Ether
// #2 Cases - Pay in Other Token // not usable until the MelonPort guys add DAI as a token on Kovan Kyber Network

contract MakerPay is LoanPay {

    // keep payWith "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" and payWithAmt "0" if making CDP with ETH
    function DeferredPay(address payTo, uint daiAmt, address payWith, uint payWithAmt) public payable {
        uint ethertolock = msg.value;

        // if not allowance first give the allowance
        if (payWith != ETHToken) {
            token tokenFunctions = token(payWith);
            tokenFunctions.transferFrom(msg.sender, address(this), payWithAmt);
            // also provide allowance to Kyber Network Proxy contract first
            Kyber kyberFunctions = Kyber(KyberAddress);
            ethertolock = kyberFunctions.trade.value(0)(
                payWith,
                payWithAmt,
                ETHToken, // dest
                address(this), // address(this)
                2**256 - 1,
                0,
                0
            );
        }

        // if CDP already created then get passed off
        if (BorrowerCDP[msg.sender] == 0x0000000000000000000000000000000000000000000000000000000000000000) {
            BorrowerCDP[msg.sender] = openCDP();
        }

        // interchanging required tokens
        ETH_WETH(ethertolock);
        WETH_PETH(ethertolock - ethertolock/1000);
        PETH_CDP(ethertolock - ethertolock/1000);

        // draw DAI
        DAILoanMaster.draw(BorrowerCDP[msg.sender], daiAmt);
        TransferDAI(payTo, daiAmt);
    }

    function TransferDAI(address payTo, uint daiAmt) internal {
        token tokenFunctions = token(DAI);
        tokenFunctions.transfer(payTo, daiAmt);
        AllSoldAmt[payTo] += daiAmt;
        AllSoldTx[payTo] += 1;
    }

}

contract CryptoPay is MakerPay {
    constructor() public {
        ApproveERC20();
    }
}