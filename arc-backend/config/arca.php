<?php

return [
    /*
     * Passwords for the first users (FirstUsersSeeder). Set them in .env;
     * they never live in the code. Each person can be renamed and get a new
     * password later from Administración.
     */
    'first_users' => [
        'admin_password' => env('ARCA_ADMIN_PASSWORD'),
        'standard_password' => env('ARCA_STANDARD_PASSWORD'),
    ],
];
