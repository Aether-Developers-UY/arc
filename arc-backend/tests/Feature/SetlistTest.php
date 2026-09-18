<?php

namespace Tests\Feature;

use App\Models\Setlist;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SetlistTest extends TestCase
{
    use RefreshDatabase;

    public function test_guests_cannot_list_setlists(): void
    {
        $this->getJson('/api/setlists')->assertUnauthorized();
    }

    public function test_an_authenticated_user_can_list_setlists_ordered_by_soonest_service_date(): void
    {
        $user = User::factory()->create();
        Setlist::factory()->create(['created_by' => $user->id, 'service_date' => '2026-10-01']);
        Setlist::factory()->create(['created_by' => $user->id, 'service_date' => '2026-09-20']);

        $response = $this->actingAs($user, 'sanctum')->getJson('/api/setlists');

        $response->assertOk();
        $dates = collect($response->json('data'))->pluck('service_date')->all();
        $this->assertSame(['2026-09-20', '2026-10-01'], $dates);
    }

    public function test_an_authenticated_user_can_create_a_setlist(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/setlists', [
            'service_date' => '2026-09-27',
            'name' => 'Culto de jóvenes',
        ]);

        $response->assertCreated()->assertJsonPath('data.name', 'Culto de jóvenes');
        $this->assertDatabaseHas('setlists', [
            'service_date' => '2026-09-27',
            'name' => 'Culto de jóvenes',
            'created_by' => $user->id,
        ]);
    }

    public function test_creating_a_setlist_fails_without_a_service_date(): void
    {
        $user = User::factory()->create();

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/setlists', []);

        $response->assertStatus(422)->assertJsonValidationErrors(['service_date']);
    }

    public function test_an_authenticated_user_can_view_a_single_setlist(): void
    {
        $user = User::factory()->create();
        $setlist = Setlist::factory()->create(['created_by' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')->getJson("/api/setlists/{$setlist->id}");

        $response->assertOk()->assertJsonPath('data.id', $setlist->id);
    }

    public function test_an_authenticated_user_can_update_a_setlist(): void
    {
        $user = User::factory()->create();
        $setlist = Setlist::factory()->create(['created_by' => $user->id, 'name' => 'Old name']);

        $response = $this->actingAs($user, 'sanctum')->putJson("/api/setlists/{$setlist->id}", [
            'service_date' => $setlist->service_date->format('Y-m-d'),
            'name' => 'New name',
        ]);

        $response->assertOk()->assertJsonPath('data.name', 'New name');
        $this->assertDatabaseHas('setlists', ['id' => $setlist->id, 'name' => 'New name']);
    }

    public function test_an_authenticated_user_can_delete_a_setlist(): void
    {
        $user = User::factory()->create();
        $setlist = Setlist::factory()->create(['created_by' => $user->id]);

        $response = $this->actingAs($user, 'sanctum')->deleteJson("/api/setlists/{$setlist->id}");

        $response->assertNoContent();
        $this->assertDatabaseMissing('setlists', ['id' => $setlist->id]);
    }
}
