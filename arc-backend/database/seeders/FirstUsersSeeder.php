<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use RuntimeException;

/**
 * The first people of the first version: one admin and two standard users,
 * with no annex yet: each picks theirs from Mis anexos. Safe to run again:
 * someone who already exists is left as they are (name or password changed
 * from Administración stay).
 *
 *   php artisan db:seed --class=FirstUsersSeeder
 */
class FirstUsersSeeder extends Seeder
{
    public function run(): void
    {
        $adminPassword = config('arca.first_users.admin_password');
        $standardPassword = config('arca.first_users.standard_password');
        if (blank($adminPassword) || blank($standardPassword)) {
            throw new RuntimeException('Set ARCA_ADMIN_PASSWORD and ARCA_STANDARD_PASSWORD in .env first.');
        }

        $people = [
            ['Administrador', 'admin@arca.local', 'admin', $adminPassword],
            ['Usuario estándar 1', 'estandar1@arca.local', 'standard', $standardPassword],
            ['Usuario estándar 2', 'estandar2@arca.local', 'standard', $standardPassword],
        ];

        foreach ($people as [$name, $email, $role, $password]) {
            User::firstOrCreate(
                ['email' => $email],
                ['name' => $name, 'role' => $role, 'password' => $password],
            );
        }
    }
}
