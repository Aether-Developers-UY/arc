<?php

namespace Database\Factories;

use App\Models\Setlist;
use App\Models\Song;
use Illuminate\Database\Eloquent\Factories\Factory;

class SetlistSongFactory extends Factory
{
    public function definition(): array
    {
        return [
            'setlist_id' => Setlist::factory(),
            'song_id' => Song::factory(),
            'position' => 0,
            'key' => 'G',
        ];
    }
}
