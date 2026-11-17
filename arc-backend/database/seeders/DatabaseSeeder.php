<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * A fresh install starts with the church's annexes and the first users
     * (their passwords come from .env); no test accounts.
     */
    public function run(): void
    {
        $this->call([AnnexesSeeder::class, FirstUsersSeeder::class]);
    }
}
