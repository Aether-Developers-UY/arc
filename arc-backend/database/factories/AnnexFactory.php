<?php

namespace Database\Factories;

use App\Models\Annex;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Annex>
 */
class AnnexFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => 'Anexo '.fake()->unique()->city(),
        ];
    }
}
