<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<\App\Models\Song>
 */
class SongFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'title' => fake()->sentence(3),
            'artist' => fake()->name(),
            'original_key' => fake()->randomElement(['C', 'D', 'E', 'G', 'A']),
            'tempo' => fake()->numberBetween(60, 140),
            'time_signature' => '4/4',
            'content' => "{title: Ejemplo}\n{key: G}\n\n{verse}\n[G]Cantaré de tu [D]amor\n[Em]Por siempre [C]Señor\n",
            'notes' => null,
            'created_by' => User::factory(),
        ];
    }
}
