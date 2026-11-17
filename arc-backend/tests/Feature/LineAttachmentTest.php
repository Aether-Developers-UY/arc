<?php

namespace Tests\Feature;

use App\Models\Attachment;
use App\Models\Song;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class LineAttachmentTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    private int $lineId;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
        $this->user = User::factory()->create();
        $song = Song::factory()->create(['created_by' => $this->user->id]);
        $this->lineId = $this->actingAs($this->user, 'sanctum')->postJson('/api/lines', [
            'name' => 'Alabanza', 'key' => 'G', 'songs' => [['song_id' => $song->id]],
        ])->json('data.id');
    }

    private function upload(string $name = 'ensayo.mp3', string $type = 'audio', string $mime = 'audio/mpeg')
    {
        return $this->actingAs($this->user, 'sanctum')->postJson("/api/lines/{$this->lineId}/attachments", [
            'type' => $type,
            'file' => UploadedFile::fake()->create($name, 500, $mime),
        ]);
    }

    public function test_a_file_can_be_attached_to_a_line(): void
    {
        $this->upload()->assertCreated()->assertJsonPath('data.original_name', 'ensayo.mp3');

        $this->assertDatabaseHas('attachments', ['line_id' => $this->lineId, 'song_id' => null, 'type' => 'audio']);
        Storage::disk('public')->assertExists(Attachment::first()->file_path);
    }

    public function test_the_line_comes_with_its_files(): void
    {
        $this->upload('pistas.pdf', 'pdf', 'application/pdf');

        $this->actingAs($this->user, 'sanctum')->getJson("/api/lines/{$this->lineId}")
            ->assertOk()
            ->assertJsonPath('data.attachments.0.original_name', 'pistas.pdf');
        $this->actingAs($this->user, 'sanctum')->getJson('/api/lines')
            ->assertJsonPath('data.0.attachments.0.type', 'pdf');
    }

    public function test_the_same_file_rules_as_songs_apply(): void
    {
        $this->upload('virus.exe', 'other', 'application/octet-stream')
            ->assertStatus(422)
            ->assertJsonValidationErrors(['file']);
    }

    public function test_a_line_file_can_be_downloaded_and_deleted(): void
    {
        $id = $this->upload()->json('data.id');

        $this->actingAs($this->user, 'sanctum')->get("/api/attachments/{$id}/download")->assertOk();
        $path = Attachment::find($id)->file_path;
        $this->actingAs($this->user, 'sanctum')->deleteJson("/api/attachments/{$id}")->assertNoContent();

        Storage::disk('public')->assertMissing($path);
    }

    public function test_deleting_a_line_deletes_its_files(): void
    {
        $this->upload();
        $path = Attachment::first()->file_path;

        $this->actingAs($this->user, 'sanctum')->deleteJson("/api/lines/{$this->lineId}")->assertNoContent();

        $this->assertDatabaseCount('attachments', 0);
        Storage::disk('public')->assertMissing($path);
    }

    public function test_editing_a_line_keeps_its_files(): void
    {
        $this->upload();
        $song = Song::factory()->create(['created_by' => $this->user->id]);

        $this->actingAs($this->user, 'sanctum')->putJson("/api/lines/{$this->lineId}", [
            'name' => 'Otra', 'key' => 'A', 'songs' => [['song_id' => $song->id]],
        ])->assertOk()->assertJsonCount(1, 'data.attachments');
    }

    public function test_song_files_do_not_show_up_in_lines(): void
    {
        $song = Song::factory()->create(['created_by' => $this->user->id]);
        $this->actingAs($this->user, 'sanctum')->postJson("/api/songs/{$song->id}/attachments", [
            'type' => 'audio',
            'file' => UploadedFile::fake()->create('cancion.mp3', 500, 'audio/mpeg'),
        ])->assertCreated();

        $this->actingAs($this->user, 'sanctum')->getJson("/api/lines/{$this->lineId}")
            ->assertJsonCount(0, 'data.attachments');
    }
}
