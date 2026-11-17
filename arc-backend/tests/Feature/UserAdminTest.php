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
        User::factory()->create(['name' => 'Ana', 'username' => 'ana']);

        $this->actingAs($admin, 'sanctum')->getJson('/api/users')
            ->assertOk()
            ->assertJsonPath('data.0', ['id' => 2, 'name' => 'Ana', 'username' => 'ana', 'role' => 'standard'])
            ->assertJsonPath('data.1.name', 'Zoe');
    }

    public function test_admin_creates_a_user_who_can_log_in(): void
    {
        $admin = User::factory()->admin()->create();

        $this->actingAs($admin, 'sanctum')->postJson('/api/users', [
            'name' => 'Lucía',
            'username' => 'lucia',
            'password' => 'alabanza1',
            'role' => 'standard',
        ])->assertCreated()->assertJsonPath('data.username', 'lucia');

        $this->app['auth']->shouldUse('web');
        $this->postJson('/api/login', ['username' => 'lucia', 'password' => 'alabanza1'])->assertOk();
    }

    public function test_usernames_are_unique_whatever_the_capitals(): void
    {
        $admin = User::factory()->admin()->create(['username' => 'admin']);

        $this->actingAs($admin, 'sanctum')->postJson('/api/users', [
            'name' => 'Otro',
            'username' => ' Admin ',
            'password' => 'alabanza1',
            'role' => 'standard',
        ])->assertUnprocessable()->assertJsonValidationErrors(['username' => 'Ese nombre de usuario ya existe.']);
    }

    public function test_no_email_is_needed_nor_kept(): void
    {
        $admin = User::factory()->admin()->create();

        $this->actingAs($admin, 'sanctum')->postJson('/api/users', [
            'name' => 'Lucía',
            'username' => 'lucia',
            'password' => 'alabanza1',
            'role' => 'standard',
        ])->assertCreated()->assertJsonMissingPath('data.email');

        $this->assertFalse(\Illuminate\Support\Facades\Schema::hasColumn('users', 'email'));
    }

    public function test_a_username_is_one_word_of_letters_numbers_dots_or_dashes(): void
    {
        $admin = User::factory()->admin()->create();

        foreach (['ana maria', 'ña', 'a', 'ana@arca'] as $bad) {
            $this->actingAs($admin, 'sanctum')->postJson('/api/users', [
                'name' => 'X', 'username' => $bad, 'password' => 'alabanza1', 'role' => 'standard',
            ])->assertUnprocessable()->assertJsonValidationErrors('username');
        }

        $this->actingAs($admin, 'sanctum')->postJson('/api/users', [
            'name' => 'X', 'username' => 'ana.maria_2-b', 'password' => 'alabanza1', 'role' => 'standard',
        ])->assertCreated();
    }

    public function test_a_username_can_be_changed_and_is_used_to_log_in(): void
    {
        $admin = User::factory()->admin()->create();
        $user = User::factory()->create(['username' => 'ana', 'password' => 'alabanza1']);

        $this->actingAs($admin, 'sanctum')->putJson("/api/users/{$user->id}", ['username' => 'Ana.Perez'])
            ->assertOk()
            ->assertJsonPath('data.username', 'ana.perez');

        $this->app['auth']->shouldUse('web');
        $this->postJson('/api/login', ['username' => 'ana.perez', 'password' => 'alabanza1'])->assertOk();
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
        $user = User::factory()->create(['username' => 'equipo']);
        $token = $user->createToken('app')->plainTextToken;

        $this->actingAs($admin, 'sanctum')
            ->putJson("/api/users/{$user->id}", ['password' => 'nuevaClave9'])
            ->assertOk();

        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/me')->assertUnauthorized();
        $this->app['auth']->shouldUse('web');
        $this->postJson('/api/login', ['username' => 'equipo', 'password' => 'nuevaClave9'])->assertOk();
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
