<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * A fresh install starts with the first users only (their passwords
     * come from .env); no test accounts.
     */
    public function run(): void
    {
        $this->call(FirstUsersSeeder::class);
    }
}
