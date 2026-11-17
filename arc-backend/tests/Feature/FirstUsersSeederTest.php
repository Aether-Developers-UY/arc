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

    public function test_it_creates_one_admin_and_two_standard_users_in_the_main_annex(): void
    {
        $this->seed(FirstUsersSeeder::class);

        $admin = User::where('email', 'admin@arca.local')->firstOrFail();
        $this->assertTrue($admin->isAdmin());
        $this->assertTrue(Hash::check('clave-admin-1', $admin->password));

        foreach (['estandar1@arca.local', 'estandar2@arca.local'] as $email) {
            $user = User::where('email', $email)->firstOrFail();
            $this->assertSame('standard', $user->role);
            $this->assertTrue(Hash::check('clave-estandar-1', $user->password));
            $this->assertSame(['Anexo principal'], $user->annexes()->pluck('name')->all());
        }
    }

    public function test_running_it_again_does_not_duplicate_or_undo_changes(): void
    {
        $this->seed(FirstUsersSeeder::class);
        User::where('email', 'estandar1@arca.local')->update(['name' => 'Ana']);

        $this->seed(FirstUsersSeeder::class);

        $this->assertSame(3, User::count());
        $this->assertSame('Ana', User::where('email', 'estandar1@arca.local')->value('name'));
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
            ['admin@arca.local', 'estandar1@arca.local', 'estandar2@arca.local'],
            User::pluck('email')->all(),
        );
    }

    public function test_the_admin_can_sign_in_with_it(): void
    {
        $this->seed(FirstUsersSeeder::class);

        $this->postJson('/api/login', ['email' => 'admin@arca.local', 'password' => 'clave-admin-1'])
            ->assertOk()
            ->assertJsonPath('user.role', 'admin');
    }
}
