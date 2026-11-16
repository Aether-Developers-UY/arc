<?php

namespace Tests\Feature;

use App\Models\Setlist;
use App\Models\SetlistSong;
use App\Models\Song;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SetlistSongTest extends TestCase
{
    use RefreshDatabase;

    public function test_adding_a_song_defaults_its_key_to_the_songs_original_key(): void
    {
        $user = User::factory()->create();
        $setlist = $this->setlistFor($user);
        $song = Song::factory()->create(['created_by' => $user->id, 'original_key' => 'D']);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson("/api/setlists/{$setlist->id}/songs", ['song_id' => $song->id]);

        $response->assertCreated()->assertJsonPath('data.key', 'D');
        $this->assertDatabaseHas('setlist_songs', [
            'setlist_id' => $setlist->id,
            'song_id' => $song->id,
            'key' => 'D',
            'position' => 0,
        ]);
    }

    public function test_adding_a_song_accepts_an_explicit_key(): void
    {
        $user = User::factory()->create();
        $setlist = $this->setlistFor($user);
        $song = Song::factory()->create(['created_by' => $user->id, 'original_key' => 'D']);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson("/api/setlists/{$setlist->id}/songs", ['song_id' => $song->id, 'key' => 'A']);

        $response->assertCreated()->assertJsonPath('data.key', 'A');
    }

    public function test_adding_a_second_song_appends_it_at_the_next_position(): void
    {
        $user = User::factory()->create();
        $setlist = $this->setlistFor($user);
        $songA = Song::factory()->create(['created_by' => $user->id]);
        $songB = Song::factory()->create(['created_by' => $user->id]);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/setlists/{$setlist->id}/songs", ['song_id' => $songA->id]);
        $response = $this->actingAs($user, 'sanctum')
            ->postJson("/api/setlists/{$setlist->id}/songs", ['song_id' => $songB->id]);

        $response->assertCreated()->assertJsonPath('data.position', 1);
    }

    public function test_an_authenticated_user_can_update_the_key_of_a_setlist_song(): void
    {
        $user = User::factory()->create();
        $setlist = $this->setlistFor($user);
        $setlistSong = SetlistSong::factory()->create(['setlist_id' => $setlist->id, 'key' => 'C']);

        $response = $this->actingAs($user, 'sanctum')
            ->putJson("/api/setlists/{$setlist->id}/songs/{$setlistSong->id}", ['key' => 'E']);

        $response->assertOk()->assertJsonPath('data.key', 'E');
        $this->assertDatabaseHas('setlist_songs', ['id' => $setlistSong->id, 'key' => 'E']);
    }

    public function test_an_authenticated_user_can_remove_a_song_from_a_setlist(): void
    {
        $user = User::factory()->create();
        $setlist = $this->setlistFor($user);
        $setlistSong = SetlistSong::factory()->create(['setlist_id' => $setlist->id]);

        $response = $this->actingAs($user, 'sanctum')
            ->deleteJson("/api/setlists/{$setlist->id}/songs/{$setlistSong->id}");

        $response->assertNoContent();
        $this->assertDatabaseMissing('setlist_songs', ['id' => $setlistSong->id]);
    }

    public function test_reorder_rewrites_positions_to_match_the_given_order(): void
    {
        $user = User::factory()->create();
        $setlist = $this->setlistFor($user);
        $first = SetlistSong::factory()->create(['setlist_id' => $setlist->id, 'position' => 0]);
        $second = SetlistSong::factory()->create(['setlist_id' => $setlist->id, 'position' => 1]);
        $third = SetlistSong::factory()->create(['setlist_id' => $setlist->id, 'position' => 2]);

        $response = $this->actingAs($user, 'sanctum')
            ->putJson("/api/setlists/{$setlist->id}/reorder", [
                'setlist_song_ids' => [$third->id, $first->id, $second->id],
            ]);

        $response->assertOk();
        $this->assertDatabaseHas('setlist_songs', ['id' => $third->id, 'position' => 0]);
        $this->assertDatabaseHas('setlist_songs', ['id' => $first->id, 'position' => 1]);
        $this->assertDatabaseHas('setlist_songs', ['id' => $second->id, 'position' => 2]);
    }

    public function test_reorder_rejects_a_list_that_does_not_match_the_setlists_actual_songs(): void
    {
        $user = User::factory()->create();
        $setlist = $this->setlistFor($user);
        SetlistSong::factory()->create(['setlist_id' => $setlist->id, 'position' => 0]);

        $response = $this->actingAs($user, 'sanctum')
            ->putJson("/api/setlists/{$setlist->id}/reorder", [
                'setlist_song_ids' => [999999],
            ]);

        $response->assertStatus(422);
    }

    public function test_deleting_a_song_from_the_catalog_removes_it_from_setlists_it_was_in(): void
    {
        $user = User::factory()->create();
        $setlist = $this->setlistFor($user);
        $song = Song::factory()->create(['created_by' => $user->id]);
        $setlistSong = SetlistSong::factory()->create(['setlist_id' => $setlist->id, 'song_id' => $song->id]);

        $song->delete();

        $this->assertDatabaseMissing('setlist_songs', ['id' => $setlistSong->id]);
        $this->assertDatabaseHas('setlists', ['id' => $setlist->id]);
    }
}
