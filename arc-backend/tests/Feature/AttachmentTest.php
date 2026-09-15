<?php

namespace Tests\Feature;

use App\Models\Attachment;
use App\Models\Song;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AttachmentTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('public');
    }

    public function test_an_authenticated_user_can_upload_an_audio_attachment_to_a_song(): void
    {
        $user = User::factory()->create();
        $song = Song::factory()->create(['created_by' => $user->id]);
        $file = UploadedFile::fake()->create('pista.mp3', 5000, 'audio/mpeg');

        $response = $this->actingAs($user, 'sanctum')->postJson("/api/songs/{$song->id}/attachments", [
            'type' => 'audio',
            'file' => $file,
        ]);

        $response->assertCreated()->assertJsonPath('data.original_name', 'pista.mp3');
        $this->assertDatabaseHas('attachments', ['song_id' => $song->id, 'type' => 'audio']);
        Storage::disk('public')->assertExists(Attachment::first()->file_path);
    }

    public function test_uploading_an_attachment_fails_when_the_file_is_too_large(): void
    {
        $user = User::factory()->create();
        $song = Song::factory()->create(['created_by' => $user->id]);
        $file = UploadedFile::fake()->create('pista.mp3', 25000, 'audio/mpeg'); // 25MB > 20MB limit

        $response = $this->actingAs($user, 'sanctum')->postJson("/api/songs/{$song->id}/attachments", [
            'type' => 'audio',
            'file' => $file,
        ]);

        $response->assertStatus(422)->assertJsonValidationErrors(['file']);
    }

    public function test_uploading_an_attachment_fails_with_a_disallowed_mime_type(): void
    {
        $user = User::factory()->create();
        $song = Song::factory()->create(['created_by' => $user->id]);
        $file = UploadedFile::fake()->create('malware.exe', 100, 'application/x-msdownload');

        $response = $this->actingAs($user, 'sanctum')->postJson("/api/songs/{$song->id}/attachments", [
            'type' => 'other',
            'file' => $file,
        ]);

        $response->assertStatus(422)->assertJsonValidationErrors(['file']);
    }

    public function test_an_authenticated_user_can_delete_an_attachment(): void
    {
        $user = User::factory()->create();
        $song = Song::factory()->create(['created_by' => $user->id]);
        $attachment = Attachment::factory()->create([
            'song_id' => $song->id,
            'file_path' => 'attachments/fake.mp3',
        ]);
        Storage::disk('public')->put('attachments/fake.mp3', 'contenido-falso');

        $response = $this->actingAs($user, 'sanctum')->deleteJson("/api/attachments/{$attachment->id}");

        $response->assertNoContent();
        $this->assertDatabaseMissing('attachments', ['id' => $attachment->id]);
        Storage::disk('public')->assertMissing('attachments/fake.mp3');
    }
}
