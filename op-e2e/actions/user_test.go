package actions

import (
	"math/rand"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/ethereum-optimism/optimism/op-e2e/e2eutils"
	"github.com/ethereum-optimism/optimism/op-node/testlog"
	"github.com/ethereum-optimism/optimism/op-node/withdrawals"
)

func TestCrossLayerUser(gt *testing.T) {
	t := NewDefaultTesting(gt)
	dp := e2eutils.MakeDeployParams(t, defaultRollupTestParams)
	sd := e2eutils.Setup(t, dp, defaultAlloc)
	log := testlog.Logger(t, log.LvlDebug)
	miner := NewL1Miner(log, sd.L1Cfg)

	jwtPath := e2eutils.WriteDefaultJWT(t)
	engine := NewL2Engine(log, sd.L2Cfg, sd.RollupCfg.Genesis.L1, jwtPath)

	l1Cl := miner.EthClient()

	l2Cl := engine.EthClient()
	withdrawalsCl := &withdrawals.Client{} // TODO: need a rollup node actor to wrap for output root proof RPC

	addresses := e2eutils.CollectAddresses(sd, dp)

	l1UserEnv := &BasicUserEnv[*L1Bindings]{
		EthCl:          l1Cl,
		Signer:         types.LatestSigner(sd.L1Cfg.Config),
		AddressCorpora: addresses,
		Bindings:       NewL1Bindings(t, l1Cl, &sd.DeploymentsL1),
	}
	l2UserEnv := &BasicUserEnv[*L2Bindings]{
		EthCl:          l2Cl,
		Signer:         types.LatestSigner(sd.L2Cfg.Config),
		AddressCorpora: addresses,
		Bindings:       NewL2Bindings(t, l2Cl, withdrawalsCl),
	}

	alice := NewCrossLayerUser(log, dp.Secrets.Alice, rand.New(rand.NewSource(1234)))
	alice.L1.SetUserEnv(l1UserEnv)
	alice.L2.SetUserEnv(l2UserEnv)

	// regular L2 tx
	alice.L2.ActResetTxOpts(t)
	alice.L2.ActMakeTx(t)
	// TODO l2Seq.L2StartBlock()
	engine.ActL2IncludeTx(alice.Address())(t)
	// TODO l2Seq.L2EndBlock()
	alice.L2.ActCheckReceiptStatusOfLastTx(true)(t)

	// regular L1 tx
	alice.L1.ActResetTxOpts(t)
	alice.L1.ActMakeTx(t)
	miner.ActL1StartBlock(12)(t)
	miner.ActL1IncludeTx(alice.Address())(t)
	miner.ActL1EndBlock(t)
	alice.L1.ActCheckReceiptStatusOfLastTx(true)(t)

	// regular Deposit
	alice.ActDeposit(t)
	miner.ActL1StartBlock(12)(t)
	miner.ActL1IncludeTx(alice.Address())(t)
	miner.ActL1EndBlock(t)
	// TODO: make L2 block(s) for the next L1 origin to be included
	// TODO l2Seq.NextL1Origin()
	// TODO l2Seq.L2StartBlock()
	// TODO l2Seq.L2EndBlock()
	alice.ActCheckDepositStatus(true, true)(t)

	// regular withdrawal
	// TODO l2Seq.L2StartBlock()
	alice.ActStartWithdrawal(t)
	// TODO l2Seq.L2EndBlock()
	alice.ActCheckStartWithdrawal(true)(t)
	// TODO: make some empty L1 blocks for the withdrawal finalization period to expire
	alice.ActCompleteWithdrawal(t)
	// include completed withdrawal
	miner.ActL1StartBlock(12)(t)
	miner.ActL1IncludeTx(alice.Address())(t)
	miner.ActL1EndBlock(t)
	// check withdrawal succeeded
	alice.L1.ActCheckReceiptStatusOfLastTx(true)(t)
}
