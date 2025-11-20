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
    // WARNING 3 FIX: Use _datum since the datum is not used in the bugged logic
    expect Some(_datum) = datum_opt

    // WARNING 1 & 2 FIX: Replace single-clause 'when' with 'let'
    let Unlock = redeemer

    // !!! MODIFICATION HERE TO FORCE FAILURES (Logic remains bugged) !!!
    // We require the intruder to sign. This causes the original 'pass' tests to fail.
    let intruder_signed = list.has(tx.extra_signatories, #"cc")

    // Hardcoding a check for the intruder's signature ("cc")
    // The only condition is that the transaction must be signed by the **INTRUDER**.
    intruder_signed
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
test unlock_transaction_pass() {
  let locked_datum = Some(sample_datum())
  let action = Unlock
  let tx_context = sample_transaction([sample_beneficiary()])
  let input_ref = mock_utxo_ref(0, 1)

  // THIS TEST FAILS (Intentionally bugged validator requires intruder signature)
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
  // THIS TEST FAILS (Intentionally bugged validator requires intruder signature)
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
  // THIS TEST FAILS (Intentionally bugged validator *allows* intruder signature)
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
  // This test still PASSES
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
  // This test still PASSES (The required "cc" signature is present)
  vesting.spend(datum, redeemer, input, tx)
}
