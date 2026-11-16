<?php

namespace Tests\Feature;

use App\Models\Setlist;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UserAdminTest extends TestCase
{
    use RefreshDatabase;

    public function test_standard_users_cannot_manage_users(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();

        $this->actingAs($user, 'sanctum')->getJson('/api/users')->assertForbidden();
        $this->actingAs($user, 'sanctum')->postJson('/api/users', [])->assertForbidden();
        $this->actingAs($user, 'sanctum')->putJson("/api/users/{$other->id}", ['role' => 'admin'])->assertForbidden();
        $this->actingAs($user, 'sanctum')->deleteJson("/api/users/{$other->id}")->assertForbidden();
    }

    public function test_admin_lists_users_by_name(): void
    {
        $admin = User::factory()->admin()->create(['name' => 'Zoe']);
        User::factory()->create(['name' => 'Ana', 'email' => 'ana@example.com']);

        $this->actingAs($admin, 'sanctum')->getJson('/api/users')
            ->assertOk()
            ->assertJsonPath('data.0', ['id' => 2, 'name' => 'Ana', 'email' => 'ana@example.com', 'role' => 'standard'])
            ->assertJsonPath('data.1.name', 'Zoe');
    }

    public function test_admin_creates_a_user_who_can_log_in(): void
    {
        $admin = User::factory()->admin()->create();

        $this->actingAs($admin, 'sanctum')->postJson('/api/users', [
            'name' => 'Lucía',
            'email' => 'lucia@example.com',
            'password' => 'alabanza1',
            'role' => 'standard',
        ])->assertCreated()->assertJsonPath('data.email', 'lucia@example.com');

        $this->app['auth']->shouldUse('web');
        $this->postJson('/api/login', ['email' => 'lucia@example.com', 'password' => 'alabanza1'])->assertOk();
    }

    public function test_emails_are_unique(): void
    {
        $admin = User::factory()->admin()->create(['email' => 'admin@example.com']);

        $this->actingAs($admin, 'sanctum')->postJson('/api/users', [
            'name' => 'Otro',
            'email' => 'admin@example.com',
            'password' => 'alabanza1',
            'role' => 'standard',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_admin_changes_name_and_role_without_revoking_tokens(): void
    {
        $admin = User::factory()->admin()->create();
        $user = User::factory()->create();
        $token = $user->createToken('app')->plainTextToken;

        $this->actingAs($admin, 'sanctum')
            ->putJson("/api/users/{$user->id}", ['name' => 'Nuevo nombre', 'role' => 'admin'])
            ->assertOk()
            ->assertJsonPath('data.name', 'Nuevo nombre')
            ->assertJsonPath('data.role', 'admin');

        $this->assertSame(1, $user->tokens()->count());
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/me')->assertOk();
    }

    public function test_resetting_a_password_revokes_that_users_tokens(): void
    {
        $admin = User::factory()->admin()->create();
        $user = User::factory()->create(['email' => 'equipo@example.com']);
        $token = $user->createToken('app')->plainTextToken;

        $this->actingAs($admin, 'sanctum')
            ->putJson("/api/users/{$user->id}", ['password' => 'nuevaClave9'])
            ->assertOk();

        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/me')->assertUnauthorized();
        $this->app['auth']->shouldUse('web');
        $this->postJson('/api/login', ['email' => 'equipo@example.com', 'password' => 'nuevaClave9'])->assertOk();
    }

    public function test_cannot_demote_the_last_admin(): void
    {
        $admin = User::factory()->admin()->create();

        $this->actingAs($admin, 'sanctum')
            ->putJson("/api/users/{$admin->id}", ['role' => 'standard'])
            ->assertUnprocessable()
            ->assertJsonPath('message', 'No podés quitar el rol al último admin.');
        $this->assertTrue($admin->fresh()->isAdmin());
    }

    public function test_an_admin_can_delete_another_admin(): void
    {
        $admin = User::factory()->admin()->create();
        $other = User::factory()->admin()->create();

        $this->actingAs($admin, 'sanctum')->deleteJson("/api/users/{$other->id}")->assertNoContent();
        $this->assertDatabaseMissing('users', ['id' => $other->id]);
    }

    // Only admins can delete, so the last admin could only be deleted by
    // themselves: this rule also protects the last admin.
    public function test_admin_cannot_delete_themselves(): void
    {
        $admin = User::factory()->admin()->create();

        $this->actingAs($admin, 'sanctum')
            ->deleteJson("/api/users/{$admin->id}")
            ->assertUnprocessable()
            ->assertJsonPath('message', 'No podés borrarte a vos mismo.');
    }

    public function test_deleting_a_user_keeps_their_setlists_and_revokes_tokens(): void
    {
        $admin = User::factory()->admin()->create();
        $user = User::factory()->create();
        $user->createToken('app');
        $setlist = Setlist::factory()->create(['created_by' => $user->id]);

        $this->actingAs($admin, 'sanctum')->deleteJson("/api/users/{$user->id}")->assertNoContent();

        $this->assertDatabaseHas('setlists', ['id' => $setlist->id, 'created_by' => null]);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }
}
