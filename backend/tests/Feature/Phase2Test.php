<?php

namespace Tests\Feature;

use App\Contracts\FileScanner;
use App\Exceptions\FileScanFailedException;
use App\Models\KycSubmission;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class Phase2Test extends TestCase
{
    use RefreshDatabase;

    public function test_register_returns_refresh_token_and_can_refresh_session(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Test User',
            'email' => 'test@example.com',
            'password' => 'password123',
            'role' => 'generator',
        ]);

        $response->assertOk();
        $response->assertJsonStructure([
            'data' => [
                'access_token',
                'refresh_token',
                'refresh_expires_at',
                'user',
            ],
        ]);

        $refresh = $response->json('data.refresh_token');

        $refreshResponse = $this->postJson('/api/v1/auth/refresh', [
            'refresh_token' => $refresh,
        ]);

        $refreshResponse->assertOk();
        $refreshResponse->assertJsonPath('data.user.email', 'test@example.com');
        $this->assertNotSame($refresh, $refreshResponse->json('data.refresh_token'));
    }

    public function test_otp_request_and_verify_returns_verification_token(): void
    {
        $this->postJson('/api/v1/auth/otp/request', [
            'phone' => '+254700000000',
        ])->assertOk();

        Cache::put(
            'otp_pending:+254700000000',
            ['hash' => hash('sha256', '+254700000000|'.'123456'), 'attempts' => 0],
            now()->addMinutes(5),
        );

        $verify = $this->postJson('/api/v1/auth/otp/verify', [
            'phone' => '+254700000000',
            'code' => '123456',
        ]);

        $verify->assertOk();
        $verify->assertJsonStructure(['data' => ['verificationToken', 'phone']]);
    }

    public function test_generator_can_submit_kyc(): void
    {
        Storage::fake('local');

        $user = User::factory()->create(['role' => 'generator']);

        Sanctum::actingAs($user);

        $file = UploadedFile::fake()->image('id.jpg', 100, 100);

        $response = $this->post('/api/v1/kyc/submissions', [
            'documentType' => 'national_id',
            'document' => $file,
        ]);

        $response->assertOk();
        $this->assertDatabaseHas('kyc_submissions', [
            'user_id' => $user->id,
            'document_type' => 'national_id',
            'status' => 'pending',
        ]);
    }

    public function test_kyc_submission_rejects_file_when_security_scan_fails(): void
    {
        Storage::fake('local');

        $this->app->bind(FileScanner::class, fn () => new class implements FileScanner
        {
            public function assertClean(string $absolutePath): void
            {
                throw new FileScanFailedException('scan failed');
            }
        });

        $user = User::factory()->create(['role' => 'generator']);

        Sanctum::actingAs($user);

        $file = UploadedFile::fake()->image('id.jpg', 100, 100);

        $response = $this->post('/api/v1/kyc/submissions', [
            'documentType' => 'national_id',
            'document' => $file,
        ]);

        $response->assertStatus(422);
        $response->assertJsonFragment(['message' => 'File failed security scan.']);
        $this->assertDatabaseCount('kyc_submissions', 0);
    }

    public function test_admin_can_review_kyc(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $user = User::factory()->create(['role' => 'generator', 'kyc_status' => 'pending']);

        $submission = KycSubmission::query()->create([
            'user_id' => $user->id,
            'status' => 'pending',
            'document_type' => 'national_id',
            'storage_path' => 'kyc/x/doc.jpg',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->patchJson('/api/v1/admin/kyc/submissions/'.$submission->public_id, [
            'status' => 'approved',
        ]);

        $response->assertOk();
        $user->refresh();
        $this->assertSame('verified', $user->kyc_status);
        $this->assertTrue($user->is_verified);
    }
}
