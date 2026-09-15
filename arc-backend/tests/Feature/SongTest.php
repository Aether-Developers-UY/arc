<?php

namespace Tests\Feature;

use App\Models\Song;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SongTest extends TestCase
{
    use RefreshDatabase;

    public function test_guests_cannot_list_songs(): void
    {
        $this->getJson('/api/songs')->assertUnauthorized();
    }

    public function test_an_authenticated_user_can_list_songs(): void
    {
        $user = User::factory()->create();
        Song::factory()->count(3)->create(['created_by' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')->getJson('/api/songs');

        $response->assertOk()->assertJsonCount(3, 'data');
    }

    public function test_an_authenticated_user_can_search_songs_by_title(): void
    {
        $user = User::factory()->create();
        Song::factory()->create(['title' => 'Sublime Gracia', 'created_by' => $user->id]);
        Song::factory()->create(['title' => 'Cuán Grande Es Él', 'created_by' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')->getJson('/api/songs?search=Gracia');

        $response->assertOk()->assertJsonCount(1, 'data');
    }

    public function test_an_authenticated_user_can_create_a_song(): void
    {
        $user = User::factory()->create();

        $payload = [
            'title' => 'Sublime Gracia',
            'artist' => 'John Newton',
            'original_key' => 'G',
            'tempo' => 80,
            'time_signature' => '3/4',
            'content' => "{verse}\n[G]Sublime [C]gracia\n",
        ];

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/songs', $payload);

        $response->assertCreated()->assertJsonPath('data.title', 'Sublime Gracia');
        $this->assertDatabaseHas('songs', ['title' => 'Sublime Gracia', 'created_by' => $user->id]);
    }

    public function test_creating_a_song_fails_without_required_fields(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/songs', []);

        $response->assertStatus(422)->assertJsonValidationErrors(['title', 'original_key', 'content']);
    }

    public function test_an_authenticated_user_can_view_a_single_song(): void
    {
        $user = User::factory()->create();
        $song = Song::factory()->create(['created_by' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')->getJson("/api/songs/{$song->id}");

        $response->assertOk()->assertJsonPath('data.id', $song->id);
    }

    public function test_an_authenticated_user_can_update_a_song(): void
    {
        $user = User::factory()->create();
        $song = Song::factory()->create(['created_by' => $user->id, 'title' => 'Old Title']);

        $response = $this->actingAs($user, 'sanctum')->putJson("/api/songs/{$song->id}", [
            'title' => 'New Title',
            'original_key' => $song->original_key,
            'content' => $song->content,
        ]);

        $response->assertOk()->assertJsonPath('data.title', 'New Title');
        $this->assertDatabaseHas('songs', ['id' => $song->id, 'title' => 'New Title']);
    }

    public function test_an_authenticated_user_can_delete_a_song(): void
    {
        $user = User::factory()->create();
        $song = Song::factory()->create(['created_by' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')->deleteJson("/api/songs/{$song->id}");

        $response->assertNoContent();
        $this->assertDatabaseMissing('songs', ['id' => $song->id]);
    }
}
