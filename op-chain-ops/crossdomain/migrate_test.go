package crossdomain_test

import (
	"fmt"
	"math/big"
	"testing"

	"github.com/ethereum-optimism/optimism/op-bindings/predeploys"
	"github.com/ethereum-optimism/optimism/op-chain-ops/crossdomain"
	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"
)

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
