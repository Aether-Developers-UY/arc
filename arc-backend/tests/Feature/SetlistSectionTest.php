<?php

namespace Tests\Feature;

use App\Models\Setlist;
use App\Models\Song;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * A service runs in blocks: an opening song, a line of songs played
 * together, the offering, and the Lord's Supper when there is one.
 */
class SetlistSectionTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    private Setlist $setlist;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = User::factory()->create();
        $this->setlist = $this->setlistFor($this->user);
    }

    private function song(string $key = 'G'): Song
    {
        return Song::factory()->create(['created_by' => $this->user->id, 'original_key' => $key]);
    }

    private function add(Song $song, ?string $section, array $extra = [])
    {
        return $this->actingAs($this->user, 'sanctum')->postJson(
            "/api/setlists/{$this->setlist->id}/songs",
            ['song_id' => $song->id, 'section' => $section, ...$extra],
        );
    }

    private function line(string $name, array $songs): int
    {
        return $this->actingAs($this->user, 'sanctum')->postJson('/api/lines', [
            'name' => $name,
            'key' => 'G',
            'songs' => array_map(fn ($s) => is_array($s) ? $s : ['song_id' => $s->id], $songs),
        ])->json('data.id');
    }

    /** [song_id, section] in the order the setlist plays them. */
    private function order(): array
    {
        return collect($this->actingAs($this->user, 'sanctum')
            ->getJson("/api/setlists/{$this->setlist->id}")
            ->json('data.setlist_songs'))
            ->map(fn ($s) => [$s['song_id'], $s['section']])
            ->all();
    }

    public function test_a_song_is_added_to_a_block(): void
    {
        $song = $this->song();

        $this->add($song, 'ofrenda')->assertCreated()->assertJsonPath('data.section', 'ofrenda');
    }

    public function test_only_the_known_blocks_are_accepted(): void
    {
        $this->add($this->song(), 'postre')->assertStatus(422)->assertJsonValidationErrors(['section']);
    }

    public function test_the_setlist_plays_its_blocks_in_service_order_whatever_the_order_they_were_added(): void
    {
        [$cena, $ofrenda, $inicio, $linea] = [$this->song(), $this->song(), $this->song(), $this->song()];
        $this->add($cena, 'santa_cena');
        $this->add($ofrenda, 'ofrenda');
        $this->add($linea, 'linea');
        $this->add($inicio, 'inicio');

        $this->assertSame([
            [$inicio->id, 'inicio'],
            [$linea->id, 'linea'],
            [$ofrenda->id, 'ofrenda'],
            [$cena->id, 'santa_cena'],
        ], $this->order());
    }

    public function test_songs_from_before_the_blocks_stay_at_the_end(): void
    {
        $old = $this->song();
        $this->add($old, null);
        $inicio = $this->song();
        $this->add($inicio, 'inicio');

        $this->assertSame([[$inicio->id, 'inicio'], [$old->id, null]], $this->order());
    }

    public function test_choosing_a_line_brings_its_songs_and_keys_into_the_line_block(): void
    {
        [$a, $b] = [$this->song('G'), $this->song('D')];
        $lineId = $this->line('Alabanza', [['song_id' => $a->id, 'key' => 'A'], $b]);
        $inicio = $this->song();
        $ofrenda = $this->song();
        $this->add($inicio, 'inicio');
        $this->add($ofrenda, 'ofrenda');

        $response = $this->actingAs($this->user, 'sanctum')
            ->putJson("/api/setlists/{$this->setlist->id}/line", ['line_id' => $lineId]);

        $response->assertOk()
            ->assertJsonPath('data.setlist_songs.1.key', 'A')
            ->assertJsonPath('data.setlist_songs.1.line.name', 'Alabanza')
            ->assertJsonPath('data.setlist_songs.2.key', 'G'); // the line's key
        $this->assertSame([
            [$inicio->id, 'inicio'],
            [$a->id, 'linea'],
            [$b->id, 'linea'],
            [$ofrenda->id, 'ofrenda'],
        ], $this->order());
    }

    public function test_choosing_another_line_replaces_the_previous_one(): void
    {
        [$a, $b, $c] = [$this->song(), $this->song(), $this->song()];
        $first = $this->line('Primera', [$a, $b]);
        $second = $this->line('Segunda', [$c]);

        $this->actingAs($this->user, 'sanctum')->putJson("/api/setlists/{$this->setlist->id}/line", ['line_id' => $first]);
        $this->actingAs($this->user, 'sanctum')->putJson("/api/setlists/{$this->setlist->id}/line", ['line_id' => $second])
            ->assertOk();

        $this->assertSame([[$c->id, 'linea']], $this->order());
    }

    public function test_editing_a_line_later_does_not_change_setlists_that_already_used_it(): void
    {
        [$a, $b] = [$this->song(), $this->song()];
        $lineId = $this->line('Alabanza', [$a]);
        $this->actingAs($this->user, 'sanctum')->putJson("/api/setlists/{$this->setlist->id}/line", ['line_id' => $lineId]);

        $this->actingAs($this->user, 'sanctum')->putJson("/api/lines/{$lineId}", [
            'name' => 'Alabanza', 'key' => 'G', 'songs' => [['song_id' => $b->id]],
        ]);
        $this->actingAs($this->user, 'sanctum')->deleteJson("/api/lines/{$lineId}");

        $this->assertSame([[$a->id, 'linea']], $this->order());
    }

    public function test_another_annexs_setlist_cannot_get_a_line(): void
    {
        $lineId = $this->line('Alabanza', [$this->song()]);
        $stranger = User::factory()->create();

        $this->actingAs($stranger, 'sanctum')
            ->putJson("/api/setlists/{$this->setlist->id}/line", ['line_id' => $lineId])
            ->assertNotFound();
    }

    public function test_reordering_keeps_each_song_in_its_block(): void
    {
        [$inicio, $l1, $l2] = [$this->song(), $this->song(), $this->song()];
        $ids = [
            $this->add($inicio, 'inicio')->json('data.id'),
            $this->add($l1, 'linea')->json('data.id'),
            $this->add($l2, 'linea')->json('data.id'),
        ];

        // Swap the two line songs, and try to sneak the opening song last.
        $this->actingAs($this->user, 'sanctum')->putJson(
            "/api/setlists/{$this->setlist->id}/reorder",
            ['setlist_song_ids' => [$ids[2], $ids[1], $ids[0]]],
        )->assertOk();

        $this->assertSame([
            [$inicio->id, 'inicio'],
            [$l2->id, 'linea'],
            [$l1->id, 'linea'],
        ], $this->order());
    }

    public function test_removing_a_song_closes_the_gap(): void
    {
        [$a, $b, $c] = [$this->song(), $this->song(), $this->song()];
        $this->add($a, 'linea');
        $middle = $this->add($b, 'linea')->json('data.id');
        $this->add($c, 'linea');

        $this->actingAs($this->user, 'sanctum')
            ->deleteJson("/api/setlists/{$this->setlist->id}/songs/{$middle}")->assertNoContent();
        $d = $this->song();
        $this->add($d, 'linea');

        $this->assertSame([[$a->id, 'linea'], [$c->id, 'linea'], [$d->id, 'linea']], $this->order());
    }
}
