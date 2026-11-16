<?php

namespace Tests\Feature;

use App\Models\Annex;
use App\Models\Setlist;
use App\Models\SetlistSong;
use App\Models\Song;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SetlistAnnexScopeTest extends TestCase
{
    use RefreshDatabase;

    private function memberOf(Annex ...$annexes): User
    {
        $user = User::factory()->create();
        $user->annexes()->attach(collect($annexes)->pluck('id'));

        return $user;
    }

    public function test_index_only_returns_setlists_of_my_annexes(): void
    {
        [$mine, $other] = Annex::factory()->count(2)->create();
        $visible = Setlist::factory()->create(['annex_id' => $mine->id]);
        Setlist::factory()->create(['annex_id' => $other->id]);

        $response = $this->actingAs($this->memberOf($mine), 'sanctum')->getJson('/api/setlists');

        $response->assertOk();
        $this->assertSame([$visible->id], collect($response->json('data'))->pluck('id')->all());
        $response->assertJsonPath('data.0.annex_id', $mine->id);
    }

    public function test_index_filters_by_annex_id(): void
    {
        [$centro, $norte] = Annex::factory()->count(2)->create();
        Setlist::factory()->create(['annex_id' => $centro->id]);
        $inNorte = Setlist::factory()->create(['annex_id' => $norte->id]);

        $response = $this->actingAs($this->memberOf($centro, $norte), 'sanctum')
            ->getJson("/api/setlists?annex_id={$norte->id}");

        $this->assertSame([$inNorte->id], collect($response->json('data'))->pluck('id')->all());
    }

    public function test_index_with_an_annex_i_am_not_in_is_404(): void
    {
        [$mine, $other] = Annex::factory()->count(2)->create();

        $this->actingAs($this->memberOf($mine), 'sanctum')
            ->getJson("/api/setlists?annex_id={$other->id}")
            ->assertNotFound();
    }

    public function test_show_update_and_delete_of_another_annexs_setlist_are_404(): void
    {
        [$mine, $other] = Annex::factory()->count(2)->create();
        $setlist = Setlist::factory()->create(['annex_id' => $other->id, 'name' => 'Ajeno']);
        $user = $this->memberOf($mine);

        $this->actingAs($user, 'sanctum')->getJson("/api/setlists/{$setlist->id}")->assertNotFound();
        $this->actingAs($user, 'sanctum')
            ->putJson("/api/setlists/{$setlist->id}", ['service_date' => '2026-12-01', 'name' => 'Mío'])
            ->assertNotFound();
        $this->actingAs($user, 'sanctum')->deleteJson("/api/setlists/{$setlist->id}")->assertNotFound();

        $this->assertDatabaseHas('setlists', ['id' => $setlist->id, 'name' => 'Ajeno']);
    }

    public function test_nested_routes_of_another_annexs_setlist_are_404(): void
    {
        [$mine, $other] = Annex::factory()->count(2)->create();
        $setlist = Setlist::factory()->create(['annex_id' => $other->id]);
        $song = Song::factory()->create();
        $setlistSong = SetlistSong::factory()->create(['setlist_id' => $setlist->id, 'song_id' => $song->id]);
        $user = $this->memberOf($mine);
        $base = "/api/setlists/{$setlist->id}";

        $this->actingAs($user, 'sanctum')->postJson("$base/songs", ['song_id' => $song->id])->assertNotFound();
        $this->actingAs($user, 'sanctum')
            ->putJson("$base/songs/{$setlistSong->id}", ['key' => 'D'])->assertNotFound();
        $this->actingAs($user, 'sanctum')->deleteJson("$base/songs/{$setlistSong->id}")->assertNotFound();
        $this->actingAs($user, 'sanctum')
            ->putJson("$base/reorder", ['setlist_song_ids' => [$setlistSong->id]])->assertNotFound();

        $this->assertDatabaseCount('setlist_songs', 1);
    }

    public function test_a_song_of_another_setlist_cannot_be_reached_through_mine(): void
    {
        [$mine, $other] = Annex::factory()->count(2)->create();
        $mySetlist = Setlist::factory()->create(['annex_id' => $mine->id]);
        $foreign = SetlistSong::factory()->create([
            'setlist_id' => Setlist::factory()->create(['annex_id' => $other->id])->id,
            'key' => 'G',
        ]);
        $user = $this->memberOf($mine);
        $route = "/api/setlists/{$mySetlist->id}/songs/{$foreign->id}";

        $this->actingAs($user, 'sanctum')->putJson($route, ['key' => 'D'])->assertNotFound();
        $this->actingAs($user, 'sanctum')->deleteJson($route)->assertNotFound();

        $this->assertDatabaseHas('setlist_songs', ['id' => $foreign->id, 'key' => 'G']);
    }

    public function test_creating_a_setlist_in_my_annex(): void
    {
        $annex = Annex::factory()->create();

        $this->actingAs($this->memberOf($annex), 'sanctum')
            ->postJson('/api/setlists', ['service_date' => '2026-12-01', 'annex_id' => $annex->id])
            ->assertCreated()
            ->assertJsonPath('data.annex_id', $annex->id);
    }

    public function test_creating_a_setlist_in_an_annex_i_am_not_in_is_rejected(): void
    {
        [$mine, $other] = Annex::factory()->count(2)->create();

        $this->actingAs($this->memberOf($mine), 'sanctum')
            ->postJson('/api/setlists', ['service_date' => '2026-12-01', 'annex_id' => $other->id])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('annex_id');
    }

    public function test_creating_without_annex_id_uses_my_first_annex(): void
    {
        $first = Annex::factory()->create();
        $second = Annex::factory()->create();

        $this->actingAs($this->memberOf($second, $first), 'sanctum')
            ->postJson('/api/setlists', ['service_date' => '2026-12-01'])
            ->assertCreated()
            ->assertJsonPath('data.annex_id', $first->id);
    }

    public function test_creating_without_annex_id_and_no_annexes_is_422(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum')
            ->postJson('/api/setlists', ['service_date' => '2026-12-01'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('annex_id');
    }

    public function test_admins_also_need_to_join_to_see_setlists(): void
    {
        $setlist = Setlist::factory()->create();
        $admin = User::factory()->admin()->create();

        $this->actingAs($admin, 'sanctum')->getJson('/api/setlists')->assertOk()->assertJsonCount(0, 'data');
        $this->actingAs($admin, 'sanctum')->getJson("/api/setlists/{$setlist->id}")->assertNotFound();
    }
}
