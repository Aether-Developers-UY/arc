<?php

namespace Database\Factories;

use App\Models\Song;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<\App\Models\Attachment>
 */
class AttachmentFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'song_id' => Song::factory(),
            'type' => 'audio',
            'original_name' => 'fake.mp3',
            'file_path' => 'attachments/fake.mp3',
            'mime_type' => 'audio/mpeg',
            'size' => 12345,
        ];
    }
}
