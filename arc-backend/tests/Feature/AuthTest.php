<?php

namespace Tests\Feature;

use App\Models\Annex;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_user_can_log_in_with_valid_credentials_and_receives_a_token(): void
    {
        $user = User::factory()->create([
            'email' => 'musico@example.com',
            'password' => bcrypt('secret123'),
        ]);

        $response = $this->postJson('/api/login', [
            'email' => 'musico@example.com',
            'password' => 'secret123',
        ]);

        $response->assertOk()->assertJsonStructure(['token', 'user' => ['id', 'name', 'email']]);
    }

    public function test_login_fails_with_invalid_credentials(): void
    {
        User::factory()->create([
            'email' => 'musico@example.com',
            'password' => bcrypt('secret123'),
        ]);

        $response = $this->postJson('/api/login', [
            'email' => 'musico@example.com',
            'password' => 'wrong-password',
        ]);

        $response->assertStatus(422);
    }

    public function test_an_authenticated_user_can_fetch_their_own_profile(): void
    {
        $user = User::factory()->create(['name' => 'Musico Test', 'email' => 'musico@example.com']);
        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/me');

        $response->assertOk()->assertJsonPath('user.email', 'musico@example.com');
    }

    public function test_me_includes_role_and_annexes(): void
    {
        $user = User::factory()->admin()->create();
        $second = Annex::factory()->create(['name' => 'Norte']);
        $first = Annex::factory()->create(['name' => 'Centro']);
        $user->annexes()->attach([$first->id, $second->id]);

        $this->actingAs($user, 'sanctum')->getJson('/api/me')
            ->assertOk()
            ->assertJsonPath('user.role', 'admin')
            ->assertJsonPath('user.annexes', [
                ['id' => $second->id, 'name' => 'Norte'],
                ['id' => $first->id, 'name' => 'Centro'],
            ]);
    }

    public function test_login_returns_role_and_annexes(): void
    {
        $user = User::factory()->create(['email' => 'equipo@example.com', 'password' => 'secret123']);
        $annex = Annex::factory()->create(['name' => 'Centro']);
        $user->annexes()->attach($annex);

        $this->postJson('/api/login', ['email' => 'equipo@example.com', 'password' => 'secret123'])
            ->assertOk()
            ->assertJsonPath('user.role', 'standard')
            ->assertJsonPath('user.annexes', [['id' => $annex->id, 'name' => 'Centro']]);
    }

    public function test_guests_cannot_fetch_the_profile_endpoint(): void
    {
        $this->getJson('/api/me')->assertUnauthorized();
    }

    public function test_an_authenticated_user_can_log_out_invalidating_the_token(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $response = $this->withHeader('Authorization', "Bearer {$token}")
            ->postJson('/api/logout');

        $response->assertOk();
        $this->assertSame(0, $user->tokens()->count());
    }
}
