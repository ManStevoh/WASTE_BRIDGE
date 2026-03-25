<?php

namespace Tests\Feature;

use App\Models\PaymentIntent;
use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletLedgerEntry;
use App\Services\WalletLedgerService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class Phase4Test extends TestCase
{
    use RefreshDatabase;

    public function test_payment_initiate_stub_when_mpesa_disabled(): void
    {
        config(['waste_bridge.mpesa.enabled' => false]);

        $user = User::factory()->create(['role' => 'generator']);
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/payment/initiate', [
            'amount' => 100.0,
            'currency' => 'KES',
        ]);

        $response->assertOk();
        $response->assertJsonPath('data.mpesa.enabled', false);
        $response->assertJsonPath('data.status', 'pending');
    }

    public function test_mpesa_stk_callback_credits_wallet_for_top_up_intent(): void
    {
        $user = User::factory()->create(['role' => 'generator']);

        $intent = PaymentIntent::create([
            'user_id' => $user->id,
            'order_id' => null,
            'amount' => 50.0,
            'currency' => 'KES',
            'provider' => 'mpesa',
            'status' => 'processing',
            'idempotency_key' => 'test-idem-'.uniqid(),
            'provider_checkout_id' => 'ws_CO_TEST_'.uniqid(),
            'raw_payload' => [],
        ]);

        $payload = [
            'Body' => [
                'stkCallback' => [
                    'MerchantRequestID' => 'mr-1',
                    'CheckoutRequestID' => $intent->provider_checkout_id,
                    'ResultCode' => 0,
                    'ResultDesc' => 'Success',
                    'CallbackMetadata' => [
                        'Item' => [
                            ['Name' => 'Amount', 'Value' => 50.0],
                            ['Name' => 'MpesaReceiptNumber', 'Value' => 'TEST123'],
                        ],
                    ],
                ],
            ],
        ];

        $this->postJson('/api/v1/webhooks/mpesa/callback', $payload)->assertOk();

        $intent->refresh();
        $this->assertSame('succeeded', $intent->status);

        $wallet = Wallet::query()->where('user_id', $user->id)->first();
        $this->assertNotNull($wallet);
        $this->assertEquals('50.00', (string) $wallet->balance);
    }

    public function test_wallet_withdraw_requires_sufficient_balance(): void
    {
        $user = User::factory()->create(['role' => 'generator']);
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/wallet/withdraw', [
            'amount' => 9999.0,
        ]);

        $response->assertStatus(422);
    }

    public function test_b2c_result_marks_withdrawal_completed(): void
    {
        $user = User::factory()->create(['role' => 'generator']);
        $wallet = $user->wallet;
        $this->assertNotNull($wallet);
        $wallet->balance = 500;
        $wallet->save();

        WalletLedgerService::debitUserAccount(
            $user,
            '100',
            'withdrawal',
            'Withdrawal test',
            'wd-b2c-complete-'.uniqid(),
            null,
            'AG_CONV_OK',
            'AG_ORIG_OK',
            'submitted',
        );

        $payload = [
            'Result' => [
                'ResultType' => 0,
                'ResultCode' => 0,
                'ResultDesc' => 'The service request is processed successfully.',
                'ConversationID' => 'AG_CONV_OK',
                'OriginatorConversationID' => 'AG_ORIG_OK',
                'ResultParameters' => [
                    'ResultParameter' => [
                        ['Key' => 'TransactionReceipt', 'Value' => 'RX_OK_1'],
                        ['Key' => 'TransactionAmount', 'Value' => 100],
                    ],
                ],
            ],
        ];

        $this->postJson('/api/v1/webhooks/mpesa/b2c/result', $payload)->assertOk();

        $entry = WalletLedgerEntry::query()->where('provider_reference', 'AG_CONV_OK')->first();
        $this->assertNotNull($entry);
        $this->assertSame('completed', $entry->payout_status);
        $this->assertSame('RX_OK_1', $entry->payout_receipt);

        $wallet->refresh();
        $this->assertSame('400.00', (string) $wallet->balance);
    }

    public function test_b2c_result_failure_reverses_wallet_debit(): void
    {
        $user = User::factory()->create(['role' => 'generator']);
        $wallet = $user->wallet;
        $this->assertNotNull($wallet);
        $wallet->balance = 500;
        $wallet->save();

        WalletLedgerService::debitUserAccount(
            $user,
            '80',
            'withdrawal',
            'Withdrawal test',
            'wd-b2c-fail-'.uniqid(),
            null,
            'AG_CONV_FAIL',
            'AG_ORIG_FAIL',
            'submitted',
        );

        $payload = [
            'Result' => [
                'ResultType' => 0,
                'ResultCode' => 2006,
                'ResultDesc' => 'Declined by bank',
                'ConversationID' => 'AG_CONV_FAIL',
                'OriginatorConversationID' => 'AG_ORIG_FAIL',
            ],
        ];

        $this->postJson('/api/v1/webhooks/mpesa/b2c/result', $payload)->assertOk();

        $wallet->refresh();
        $this->assertSame('500.00', (string) $wallet->balance);

        $reversal = WalletLedgerEntry::query()->where('idempotency_key', 'b2c-reversal-AG_CONV_FAIL')->first();
        $this->assertNotNull($reversal);
        $this->assertSame('b2c_reversal', $reversal->category);

        $debit = WalletLedgerEntry::query()->where('provider_reference', 'AG_CONV_FAIL')->first();
        $this->assertSame('failed', $debit->payout_status);
    }

    public function test_b2c_timeout_marks_withdrawal_timeout(): void
    {
        $user = User::factory()->create(['role' => 'generator']);
        $wallet = $user->wallet;
        $this->assertNotNull($wallet);
        $wallet->balance = 300;
        $wallet->save();

        WalletLedgerService::debitUserAccount(
            $user,
            '50',
            'withdrawal',
            'Withdrawal test',
            'wd-b2c-to-'.uniqid(),
            null,
            'AG_CONV_TO',
            'AG_ORIG_TO',
            'submitted',
        );

        $payload = [
            'Result' => [
                'ResultType' => 0,
                'ResultCode' => 2001,
                'ResultDesc' => 'Request timed out',
                'ConversationID' => 'AG_CONV_TO',
                'OriginatorConversationID' => 'AG_ORIG_TO',
            ],
        ];

        $this->postJson('/api/v1/webhooks/mpesa/b2c/timeout', $payload)->assertOk();

        $entry = WalletLedgerEntry::query()->where('provider_reference', 'AG_CONV_TO')->first();
        $this->assertSame('timeout', $entry->payout_status);
    }

    public function test_user_can_export_own_wallet_ledger_csv(): void
    {
        $user = User::factory()->create(['role' => 'generator']);
        Sanctum::actingAs($user);

        $response = $this->get('/api/v1/wallet/ledger/export');

        $response->assertOk();
        $response->assertHeader('content-type', 'text/csv; charset=UTF-8');
        $this->assertStringContainsString('public_id', $response->streamedContent());
    }
}
