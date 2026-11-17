<?php

namespace Tests\Feature;

use App\Models\Line;
use App\Models\Song;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LineTest extends TestCase
{
    use RefreshDatabase;

    private function songs(User $user, array $keys): array
    {
        return array_map(
            fn ($key) => Song::factory()->create(['created_by' => $user->id, 'original_key' => $key]),
            $keys,
        );
    }

    public function test_guests_cannot_see_the_lines(): void
    {
        $this->getJson('/api/lines')->assertUnauthorized();
    }

    public function test_a_line_is_created_with_its_songs_in_order_and_their_keys(): void
    {
        $user = User::factory()->create();
        [$a, $b, $c] = $this->songs($user, ['G', 'D', 'A']);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/lines', [
            'name' => 'Alabanza alegre',
            'songs' => [
                ['song_id' => $b->id, 'key' => 'E'],
                ['song_id' => $a->id],
                ['song_id' => $c->id, 'key' => 'A'],
            ],
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.name', 'Alabanza alegre')
            ->assertJsonCount(3, 'data.line_songs')
            ->assertJsonPath('data.line_songs.0.song_id', $b->id)
            ->assertJsonPath('data.line_songs.0.key', 'E')
            ->assertJsonPath('data.line_songs.1.key', 'G') // the song's own key by default
            ->assertJsonPath('data.line_songs.1.song.title', $a->title)
            ->assertJsonPath('data.line_songs.2.song_id', $c->id);
    }

    public function test_a_line_needs_a_name_and_at_least_one_song(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user, 'sanctum')->postJson('/api/lines', ['name' => '', 'songs' => []])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['name', 'songs']);
    }

    public function test_a_line_cannot_use_a_song_that_does_not_exist(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user, 'sanctum')->postJson('/api/lines', [
            'name' => 'Línea', 'songs' => [['song_id' => 999]],
        ])->assertStatus(422)->assertJsonValidationErrors(['songs.0.song_id']);
    }

    public function test_the_library_lists_every_line_by_name_with_its_songs(): void
    {
        $user = User::factory()->create();
        [$a] = $this->songs($user, ['G']);
        $this->actingAs($user, 'sanctum')->postJson('/api/lines', ['name' => 'Zeta', 'songs' => [['song_id' => $a->id]]]);
        $this->actingAs($user, 'sanctum')->postJson('/api/lines', ['name' => 'Adoración', 'songs' => [['song_id' => $a->id]]]);

        $other = User::factory()->create();
        $this->actingAs($other, 'sanctum')->getJson('/api/lines')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.name', 'Adoración')
            ->assertJsonPath('data.0.line_songs.0.song.original_key', 'G');
    }

    public function test_updating_a_line_replaces_its_name_and_songs(): void
    {
        $user = User::factory()->create();
        [$a, $b] = $this->songs($user, ['G', 'D']);
        $id = $this->actingAs($user, 'sanctum')->postJson('/api/lines', [
            'name' => 'Vieja', 'songs' => [['song_id' => $a->id], ['song_id' => $b->id]],
        ])->json('data.id');

        $this->actingAs($user, 'sanctum')->putJson("/api/lines/{$id}", [
            'name' => 'Nueva', 'songs' => [['song_id' => $b->id, 'key' => 'C']],
        ])->assertOk()
            ->assertJsonPath('data.name', 'Nueva')
            ->assertJsonCount(1, 'data.line_songs')
            ->assertJsonPath('data.line_songs.0.key', 'C');

        $this->assertDatabaseCount('line_songs', 1);
    }

    public function test_a_line_can_be_deleted(): void
    {
        $user = User::factory()->create();
        [$a] = $this->songs($user, ['G']);
        $id = $this->actingAs($user, 'sanctum')->postJson('/api/lines', [
            'name' => 'Línea', 'songs' => [['song_id' => $a->id]],
        ])->json('data.id');

        $this->actingAs($user, 'sanctum')->deleteJson("/api/lines/{$id}")->assertNoContent();

        $this->assertDatabaseCount('lines', 0);
        $this->assertDatabaseCount('line_songs', 0);
    }

    public function test_deleting_a_song_takes_it_out_of_its_lines(): void
    {
        $user = User::factory()->create();
        [$a, $b] = $this->songs($user, ['G', 'D']);
        $id = $this->actingAs($user, 'sanctum')->postJson('/api/lines', [
            'name' => 'Línea', 'songs' => [['song_id' => $a->id], ['song_id' => $b->id]],
        ])->json('data.id');

        $this->actingAs($user, 'sanctum')->deleteJson("/api/songs/{$a->id}")->assertNoContent();

        $this->assertSame(1, Line::find($id)->lineSongs()->count());
    }
}
