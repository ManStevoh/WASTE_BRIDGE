<?php

namespace Tests\Feature;

use App\Models\PaymentIntent;
use App\Models\User;
use App\Models\Wallet;
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
}
