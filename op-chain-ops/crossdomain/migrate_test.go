package crossdomain_test

import (
	"fmt"
	"math/big"
	"testing"

	"github.com/ethereum-optimism/optimism/op-bindings/bindings"
	"github.com/ethereum-optimism/optimism/op-bindings/predeploys"
	"github.com/ethereum-optimism/optimism/op-chain-ops/crossdomain"
	"github.com/ethereum-optimism/optimism/op-chain-ops/state"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/vm"
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

func setOptimismPortal(db vm.StateDB) error {
	// I think we want immutable impl here?
	bytecode, err := bindings.GetDeployedBytecode("OptimismPortal")
	if err != nil {
		return err
	}

	db.CreateAccount(predeploys.DevOptimismPortalAddr)
	db.SetCode(predeploys.DevOptimismPortalAddr, bytecode)

	// TODO: what needs to be set in the optimism portal?
	return state.SetStorage(
		"OptimismPortal",
		predeploys.DevOptimismPortalAddr,
		state.StorageValues{},
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
	L2db := state.NewMemoryStateDB(nil)

	// Set the test account and give it a large balance
	L2db.CreateAccount(testAccount)
	L2db.AddBalance(testAccount, big.NewInt(10000000000000000))

	err := setL2ToL1MessagePasser(L2db)
	require.Nil(t, err)
}
