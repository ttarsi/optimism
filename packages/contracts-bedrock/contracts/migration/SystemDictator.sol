// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { L1CrossDomainMessenger } from "../L1/L1CrossDomainMessenger.sol";
import { L1StandardBridge } from "../L1/L1StandardBridge.sol";
import { OptimismPortal } from "../L1/OptimismPortal.sol";
import { L2OutputOracle } from "../L1/L2OutputOracle.sol";
import { Proxy } from "../universal/Proxy.sol";
import { ProxyAdmin } from "../universal/ProxyAdmin.sol";
import { OptimismMintableERC20 } from "../universal/OptimismMintableERC20.sol";
import { OptimismMintableERC20Factory } from "../universal/OptimismMintableERC20Factory.sol";
import { AddressManager } from "../legacy/AddressManager.sol";
import { L1ChugSplashProxy } from "../legacy/L1ChugSplashProxy.sol";

contract StaticSender {
    function send(OptimismPortal _portal) public {
        _portal.donateETH{value: address(this).balance}();
    }
}

contract SystemDictator is Ownable {
    struct GeneralConfig {
        address owner;
        address multisig;
        bytes32[] zeroslots;
    }

    struct OldContractConfig {
        L1CrossDomainMessenger l1CrossDomainMessenger;
        L1StandardBridge l1StandardBridge;
        AddressManager addressManager;
        ProxyAdmin proxyAdmin;
    }

    struct NewContractConfig {
        Proxy proxyOptimismMintableERC20Factory;
        Proxy proxyL2OutputOracle;
        Proxy proxyOptimismPortal;
    }

    struct ImplementationConfig {
        L1CrossDomainMessenger implL1CrossDomainMessenger;
        L1StandardBridge implL1StandardBridge;
        OptimismMintableERC20 implOptimismMintableERC20Factory;
        L2OutputOracle implL2OutputOracle;
        OptimismPortal implOptimismPortal;
        StaticSender implStaticSender;
    }

    struct L2OutputOracleConfig {
        bytes32 genesisL2Output;
        uint256 startingBlockNumber;
        address proposer;
        address owner;
    }

    GeneralConfig public gConfig;
    OldContractConfig public oConfig;
    NewContractConfig public nConfig;
    ImplementationConfig public iConfig;
    L2OutputOracleConfig public lConfig;

    constructor(
        GeneralConfig memory _gConfig,
        OldContractConfig memory _oConfig,
        NewContractConfig memory _nConfig,
        ImplementationConfig memory _iConfig,
        L2OutputOracleConfig memory _lConfig
    ) Ownable() {
        gConfig = _gConfig;
        oConfig = _oConfig;
        nConfig = _nConfig;
        iConfig = _iConfig;
        lConfig = _lConfig;
        transferOwnership(_gConfig.owner);
    }

    function step1() public onlyOwner {
        // Pause the L1CrossDomainMessenger
        oConfig.l1CrossDomainMessenger.pause();

        // Remove all dead addresses from the AddressManager
        string[18] memory deads = [
            "Proxy__OVM_L1CrossDomainMessenger",
            "Proxy__OVM_L1StandardBridge",
            "OVM_CanonicalTransactionChain",
            "OVM_L2CrossDomainMessenger",
            "OVM_DecompressionPrecompileAddress",
            "OVM_Sequencer",
            "OVM_Proposer",
            "OVM_ChainStorageContainer-CTC-batches",
            "OVM_ChainStorageContainer-CTC-queue",
            "OVM_CanonicalTransactionChain",
            "OVM_StateCommitmentChain",
            "OVM_BondManager",
            "OVM_ExecutionManager",
            "OVM_FraudVerifier",
            "OVM_StateManagerFactory",
            "OVM_StateTransitionerFactory",
            "OVM_SafetyChecker",
            "OVM_L1MultiMessageRelayer"
        ];

        for (uint256 i = 0; i < deads.length; i++) {
            oConfig.addressManager.setAddress(deads[i], address(0));
        }
    }

    function step2() public onlyOwner {
        // TODO: Zero out storage by upgrading contracts to temporary impls
        for (uint256 i = 0; i < gConfig.zeroslots.length; i++) {}
    }

    function step3() public onlyOwner {
        // Configure ProxyAdmin
        oConfig.proxyAdmin.setAddressManager(oConfig.addressManager);
        oConfig.proxyAdmin.setProxyType(
            address(oConfig.l1CrossDomainMessenger),
            ProxyAdmin.ProxyType.RESOLVED
        );
        oConfig.proxyAdmin.setProxyType(
            address(oConfig.l1StandardBridge),
            ProxyAdmin.ProxyType.CHUGSPLASH
        );
        oConfig.proxyAdmin.setImplementationName(
            address(oConfig.l1CrossDomainMessenger),
            "OVM_L1CrossDomainMessenger"
        );

        // Transfer ownership of AddressManager to ProxyAdmin
        oConfig.addressManager.transferOwnership(address(oConfig.proxyAdmin));

        // Transfer ownership of L1StandardBridge to ProxyAdmin
        L1ChugSplashProxy(payable(oConfig.l1StandardBridge)).setOwner(address(oConfig.proxyAdmin));
    }

    function step4() public onlyOwner {
        // Upgrade the OptimismMintableERC20Factory
        oConfig.proxyAdmin.upgrade(
            payable(nConfig.proxyOptimismMintableERC20Factory),
            address(iConfig.implOptimismMintableERC20Factory)
        );

        // Upgrade the L2OutputOracle and call initialize()
        oConfig.proxyAdmin.upgradeAndCall(
            payable(nConfig.proxyL2OutputOracle),
            address(iConfig.implL2OutputOracle),
            abi.encodeCall(
                L2OutputOracle.initialize,
                (
                    lConfig.genesisL2Output,
                    lConfig.startingBlockNumber,
                    lConfig.proposer,
                    lConfig.owner
                )
            )
        );

        // Upgrade the OptimismPortal and call initialize()
        oConfig.proxyAdmin.upgradeAndCall(
            payable(nConfig.proxyOptimismPortal),
            address(iConfig.implOptimismPortal),
            abi.encodeCall(OptimismPortal.initialize, ())
        );

        // Transfer ETH from L1StandardBridge to OptimismPortal
        oConfig.proxyAdmin.upgradeAndCall(
            payable(oConfig.l1StandardBridge),
            address(iConfig.implStaticSender),
            abi.encodeCall(
                StaticSender.send,
                (OptimismPortal(payable(nConfig.proxyOptimismPortal)))
            )
        );

        // Upgrade the L1StandardBridge and call initialize()
        oConfig.proxyAdmin.upgradeAndCall(
            payable(oConfig.l1StandardBridge),
            address(iConfig.implL1StandardBridge),
            abi.encodeCall(
                L1StandardBridge.initialize,
                (payable(address(oConfig.l1CrossDomainMessenger)))
            )
        );

        // Upgrade the L1CrossDomainMessenger and call initialize()
        oConfig.proxyAdmin.upgradeAndCall(
            payable(address(oConfig.l1CrossDomainMessenger)),
            address(iConfig.implL1CrossDomainMessenger),
            abi.encodeCall(L1CrossDomainMessenger.initialize, ())
        );
    }

    function step5() public onlyOwner {
        // Unpause the L1CrossDomainMessenger
        oConfig.l1CrossDomainMessenger.unpause();
    }

    function step6() public onlyOwner {
        // Transfer ownership of the L1CrossDomainMessenger to multisig
        oConfig.l1CrossDomainMessenger.transferOwnership(address(gConfig.multisig));

        // Transfer ownership of the ProxyAdmin to multisig
        oConfig.proxyAdmin.setOwner(address(gConfig.multisig));
    }
}
