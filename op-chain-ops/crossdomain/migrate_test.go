package crossdomain_test

import (
	"fmt"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/core/vm"

	"github.com/ethereum-optimism/optimism/op-bindings/bindings"
	"github.com/ethereum-optimism/optimism/op-bindings/predeploys"
	"github.com/ethereum-optimism/optimism/op-chain-ops/crossdomain"
	"github.com/ethereum-optimism/optimism/op-chain-ops/genesis"
	"github.com/ethereum-optimism/optimism/op-chain-ops/state"

	"github.com/stretchr/testify/require"
)

func setLegacyMessagePasser(db vm.StateDB, successful []common.Hash) error {
	bytecode, err := bindings.GetDeployedBytecode("LegacyMessagePasser")
	if err != nil {
		return err
	}

	db.CreateAccount(predeploys.LegacyMessagePasserAddr)
	db.SetCode(predeploys.LegacyMessagePasserAddr, bytecode)

	msgs := make(map[any]any)
	for _, hash := range successful {
		msgs[hash] = true
	}

	return state.SetStorage(
		"LegacyMessagePasser",
		predeploys.LegacyMessagePasserAddr,
		state.StorageValues{
			"successfulMessages": msgs,
		},
		db,
	)
}

// TODO: needs a case for eth withdrawals
func TestMigrateWithdrawal(t *testing.T) {
	target := common.Address{}
	sender := common.Address{}
	data := []byte{}
	nonce := new(big.Int).SetUint64(20)

	legacy := crossdomain.NewLegacyWithdrawal(&target, &sender, data, nonce)
	withdrawal, err := crossdomain.MigrateWithdrawal(legacy)
	require.Nil(t, err)
	require.NotNil(t, withdrawal)

	// TODO: test all the things
	fmt.Printf("%#v\n", withdrawal)

	require.Equal(t, nonce.Uint64(), withdrawal.Nonce.Uint64())
	require.Equal(t, *withdrawal.Sender, predeploys.L2CrossDomainMessengerAddr)
	require.Equal(t, *withdrawal.Target, target)
}

// - create L1 with
//   - OptimismPortal
//   - L1CrossDomainMessenger
//   - L1StandardBridge
//   - L2OutputOracle
// - create L2 with LegacyMessagePasser, L2ToL1MessagePasser
// - build list of pending withdrawals
// - place legacy storage slots in legacy message passer
// - call MigrateWithdrawals
// - send output commitment to L2OutputOracle
// - Attempt to withdraw the PendingWithdrawals
func TestMigrateWithdrawals(t *testing.T) {
	// Create a L2 db
	//L2db := state.NewMemoryStateDB(nil)

	cfg := genesis.DeployConfig{
		L2ChainID:                       666,
		L1ChainID:                       667,
		FundDevAccounts:                 true,
		L2OutputOracleStartingTimestamp: -1,
		L1GenesisBlockTimestamp:         1,
		L2BlockTime:                     2,
		L2OutputOracleProposer:          common.Address{19: 0xaa},
		L2OutputOracleOwner:             common.Address{19: 0xbb},
	}

	header := types.Header{
		Number:  new(big.Int),
		BaseFee: new(big.Int),
	}
	block := types.NewBlock(&header, nil, nil, nil, nil)

	gL2, err := genesis.BuildL2DeveloperGenesis(&cfg, block, nil)
	require.Nil(t, err)

	db := state.NewMemoryStateDB(gL2)
	require.NotNil(t, db)

	// TODO: need to place some extra stuff in the genesis state now

	gL1, err := genesis.BuildL1DeveloperGenesis(&cfg)
	require.Nil(t, err)
	require.NotNil(t, gL1)
}
