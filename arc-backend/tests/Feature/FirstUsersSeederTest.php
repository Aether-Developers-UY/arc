<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\FirstUsersSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class FirstUsersSeederTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'arca.first_users.admin_password' => 'clave-admin-1',
            'arca.first_users.standard_password' => 'clave-estandar-1',
        ]);
    }

    public function test_it_creates_one_admin_and_two_standard_users_with_no_annex_yet(): void
    {
        $this->seed(FirstUsersSeeder::class);

        $admin = User::where('username', 'admin')->firstOrFail();
        $this->assertTrue($admin->isAdmin());
        $this->assertTrue(Hash::check('clave-admin-1', $admin->password));

        foreach (['estandar1', 'estandar2'] as $username) {
            $user = User::where('username', $username)->firstOrFail();
            $this->assertSame('standard', $user->role);
            $this->assertTrue(Hash::check('clave-estandar-1', $user->password));
            // Each one picks their annexes from Mis anexos.
            $this->assertSame(0, $user->annexes()->count());
        }
    }

    public function test_running_it_again_does_not_duplicate_or_undo_changes(): void
    {
        $this->seed(FirstUsersSeeder::class);
        User::where('username', 'estandar1')->update(['name' => 'Ana']);

        $this->seed(FirstUsersSeeder::class);

        $this->assertSame(3, User::count());
        $this->assertSame('Ana', User::where('username', 'estandar1')->value('name'));
    }

    public function test_it_refuses_to_run_without_passwords(): void
    {
        config(['arca.first_users.admin_password' => null]);

        $this->expectExceptionMessage('ARCA_ADMIN_PASSWORD');
        $this->seed(FirstUsersSeeder::class);
    }

    public function test_the_default_seed_creates_only_the_first_users(): void
    {
        $this->seed();

        $this->assertEqualsCanonicalizing(
            ['admin', 'estandar1', 'estandar2'],
            User::pluck('username')->all(),
        );
    }

    public function test_the_admin_can_sign_in_with_it(): void
    {
        $this->seed(FirstUsersSeeder::class);

        $this->postJson('/api/login', ['username' => 'admin', 'password' => 'clave-admin-1'])
            ->assertOk()
            ->assertJsonPath('user.role', 'admin');
    }
}
