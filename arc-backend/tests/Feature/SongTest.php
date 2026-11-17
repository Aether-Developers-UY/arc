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

    public function test_songs_can_be_found_by_a_phrase_of_their_lyrics(): void
    {
        $user = User::factory()->create();
        Song::factory()->create([
            'title' => 'Cuán Grande Es Él',
            'content' => "{verse}\n[G]Señor mi [C]Dios, al contem[G]plar los cielos\n",
            'created_by' => $user->id,
        ]);
        Song::factory()->create([
            'title' => 'Sublime Gracia',
            'content' => "[G]Sublime gracia del Se[D]ñor\n",
            'created_by' => $user->id,
        ]);

        // The chords in the middle of the phrase do not get in the way.
        $this->actingAs($user, 'sanctum')->getJson('/api/songs?search=al contemplar los')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.title', 'Cuán Grande Es Él');
    }

    public function test_the_lyrics_search_ignores_accents_and_capitals(): void
    {
        $user = User::factory()->create();
        Song::factory()->create([
            'title' => 'Cuán Grande Es Él',
            'content' => "[G]Señor mi [C]Dios\n",
            'created_by' => $user->id,
        ]);

        $this->actingAs($user, 'sanctum')->getJson('/api/songs?search=SENOR MI dios')
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_the_lyrics_search_follows_a_phrase_across_lines(): void
    {
        $user = User::factory()->create();
        Song::factory()->create([
            'title' => 'Sublime Gracia',
            'content' => "[G]Sublime gracia del Señor\n[D]que a un pecador salvó\n",
            'created_by' => $user->id,
        ]);

        $this->actingAs($user, 'sanctum')->getJson('/api/songs?search=del señor que a un')
            ->assertOk()
            ->assertJsonCount(1, 'data');
    }

    public function test_section_names_and_chords_are_not_searched_as_lyrics(): void
    {
        $user = User::factory()->create();
        Song::factory()->create([
            'title' => 'Sublime Gracia',
            'content' => "{chorus}\n[Am7]Sublime gracia\n",
            'created_by' => $user->id,
        ]);

        $this->actingAs($user, 'sanctum')->getJson('/api/songs?search=chorus')
            ->assertOk()->assertJsonCount(0, 'data');
        $this->actingAs($user, 'sanctum')->getJson('/api/songs?search=Am7')
            ->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_editing_the_lyrics_updates_what_the_search_finds(): void
    {
        $user = User::factory()->create();
        $song = Song::factory()->create([
            'title' => 'Sublime Gracia',
            'content' => "[G]Sublime gracia\n",
            'created_by' => $user->id,
        ]);

        $this->actingAs($user, 'sanctum')->putJson("/api/songs/{$song->id}", [
            'title' => 'Sublime Gracia',
            'original_key' => 'G',
            'content' => "[G]Gloria sin fin\n",
        ])->assertOk();

        $this->getJson('/api/songs?search=gloria sin')->assertJsonCount(1, 'data');
        $this->getJson('/api/songs?search=sublime gracia')->assertJsonCount(1, 'data'); // still by title
        $this->getJson('/api/songs?search=gracia')->assertJsonCount(1, 'data');
    }

    public function test_percent_and_underscore_in_the_search_are_taken_literally(): void
    {
        $user = User::factory()->create();
        Song::factory()->create(['title' => 'Sublime Gracia', 'created_by' => $user->id]);

        $this->actingAs($user, 'sanctum')->getJson('/api/songs?search=%25')
            ->assertOk()->assertJsonCount(0, 'data');
        $this->actingAs($user, 'sanctum')->getJson('/api/songs?search=_')
            ->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_the_list_does_not_carry_the_search_text(): void
    {
        $user = User::factory()->create();
        Song::factory()->create(['created_by' => $user->id]);

        $this->actingAs($user, 'sanctum')->getJson('/api/songs')
            ->assertOk()
            ->assertJsonMissingPath('data.0.lyrics');
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
