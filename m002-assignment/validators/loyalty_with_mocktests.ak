// ============================================================================
// SIGNATURE-ONLY VAULT VALIDATOR WITH TESTS - Simple Signature Contract
// ============================================================================
// This validator locks funds and allows a specific beneficiary to claim them
// immediately, provided they sign the transaction. The time-lock feature
// has been removed to resolve the dependency error.
// ============================================================================

use aiken/collection/list
use cardano/transaction.{OutputReference, Transaction, placeholder}
use mocktail.{mock_utxo_ref}

// ----------------------------------------------------------------------------
// DATUM - Data stored with locked funds
// ----------------------------------------------------------------------------

pub type VestingDatum {
  beneficiary: ByteArray,
}

// The 'unlock_time' is removed since the time dependency is gone.

// ----------------------------------------------------------------------------
// REDEEMER - Action that can be taken
// ----------------------------------------------------------------------------

pub type VestingRedeemer {
  Unlock
}

// ----------------------------------------------------------------------------
// VALIDATOR - The security logic (Simplified)
// ----------------------------------------------------------------------------

validator vesting {
  spend(
    datum_opt: Option<VestingDatum>,
    redeemer: VestingRedeemer,
    _input: OutputReference,
    tx: Transaction,
  ) {
    expect Some(datum) = datum_opt

    when redeemer is {
      Unlock -> {
        let beneficiary_signed =
          list.has(tx.extra_signatories, datum.beneficiary)

        // The only condition is that the transaction must be signed by the beneficiary.
        beneficiary_signed
      }
    }
  }

  else(_) {
    fail
  }
}

// ============================================================================
// TEST SUITE (Updated for Signature-Only Logic)
// ============================================================================

// ----------------------------------------------------------------------------
// HELPER FUNCTIONS FOR TESTS
// ----------------------------------------------------------------------------

fn sample_beneficiary() -> ByteArray {
  #"aa"
}

fn sample_intruder() -> ByteArray {
  #"cc"
}

// The 'unlock_time' field is removed from the datum.
fn sample_datum() -> VestingDatum {
  VestingDatum { beneficiary: sample_beneficiary() }
}

// The 'from_time' argument is removed from the transaction helper.
fn sample_transaction(signatories: List<ByteArray>) -> Transaction {
  Transaction { ..placeholder, extra_signatories: signatories }
}

// ============================================================================
// MOCK TRANSACTION TESTS: LOCKING & UNLOCKING
// ============================================================================

// ----------------------------------------------------------------------------
// TEST: Locking Transaction Simulation
// ----------------------------------------------------------------------------
// Note: Validators do not run during the 'Locking' phase. This test ensures
// the data we intend to lock (the Datum) is structured correctly.
test simulate_locking_transaction() {
  // 1. Define the beneficiary (Address receiving the rights)
  let beneficiary_pkh = sample_beneficiary()

  // 2. Create the Datum (The lock state)
  let datum_to_lock = VestingDatum { beneficiary: beneficiary_pkh }

  // 3. Assert the datum contains the expected data
  datum_to_lock.beneficiary == beneficiary_pkh
}

// ----------------------------------------------------------------------------
// TEST: Unlocking Transaction (Validator Pass Case)
// ----------------------------------------------------------------------------
// This simulates the transaction attempting to spend the UTxO.
test unlock_transaction_pass() {
  // 1. The Locked Data (UTxO sitting at script address)
  let locked_datum = Some(sample_datum())

  // 2. The Claim Action (Redeemer)
  let action = Unlock

  // 3. The Transaction Context (Beneficiary signs the tx)
  let tx_context = sample_transaction([sample_beneficiary()])

  // 4. The Input Reference (Pointer to the UTxO being spent)
  let input_ref = mock_utxo_ref(0, 1)

  // 5. Run Validator
  vesting.spend(locked_datum, action, input_ref, tx_context)
}

// ============================================================================
// UNIT TESTS
// ============================================================================

// ----------------------------------------------------------------------------
// TEST 1: Happy Path - Beneficiary can unlock
// ----------------------------------------------------------------------------

test beneficiary_can_unlock_with_signature() {
  let datum = Some(sample_datum())
  let redeemer = Unlock
  let tx = sample_transaction([sample_beneficiary()])
  let input = mock_utxo_ref(0, 0)
  vesting.spend(datum, redeemer, input, tx)
}

// ----------------------------------------------------------------------------
// TEST 2: Intruder cannot unlock
// ----------------------------------------------------------------------------

test intruder_cannot_unlock() {
  let datum = Some(sample_datum())
  let redeemer = Unlock
  let tx = sample_transaction([sample_intruder()])
  let input = mock_utxo_ref(0, 0)
  !vesting.spend(datum, redeemer, input, tx)
}

// ----------------------------------------------------------------------------
// TEST 3: No signature fails
// ----------------------------------------------------------------------------

test no_signature_fails() {
  let datum = Some(sample_datum())
  let redeemer = Unlock
  let tx = sample_transaction([])
  let input = mock_utxo_ref(0, 0)
  !vesting.spend(datum, redeemer, input, tx)
}

// ----------------------------------------------------------------------------
// TEST 4: Extra signatures are okay
// ----------------------------------------------------------------------------

test extra_signatures_are_okay() {
  let datum = Some(sample_datum())
  let redeemer = Unlock
  let tx = sample_transaction([sample_beneficiary(), sample_intruder()])
  let input = mock_utxo_ref(0, 0)
  vesting.spend(datum, redeemer, input, tx)
}
