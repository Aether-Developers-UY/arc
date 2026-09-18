<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class SetlistFactory extends Factory
{
    public function definition(): array
    {
        return [
            'service_date' => fake()->dateTimeBetween('now', '+2 months')->format('Y-m-d'),
            'name' => fake()->optional()->words(2, true),
            'created_by' => User::factory(),
        ];
    }
}
