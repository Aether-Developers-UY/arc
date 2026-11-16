<?php

namespace Tests\Feature;

use App\Models\Annex;
use App\Models\Setlist;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AnnexTest extends TestCase
{
    use RefreshDatabase;

    public function test_anyone_can_list_annexes_with_membership_flag(): void
    {
        $user = User::factory()->create();
        $norte = Annex::factory()->create(['name' => 'Norte']);
        $centro = Annex::factory()->create(['name' => 'Centro']);
        $user->annexes()->attach($norte);

        $this->actingAs($user, 'sanctum')->getJson('/api/annexes')
            ->assertOk()
            ->assertExactJson(['data' => [
                ['id' => $centro->id, 'name' => 'Centro', 'is_member' => false],
                ['id' => $norte->id, 'name' => 'Norte', 'is_member' => true],
            ]]);
    }

    public function test_joining_and_leaving_an_annex(): void
    {
        $user = User::factory()->create();
        $annex = Annex::factory()->create();

        $this->actingAs($user, 'sanctum')->postJson("/api/annexes/{$annex->id}/join")->assertNoContent();
        $this->actingAs($user, 'sanctum')->postJson("/api/annexes/{$annex->id}/join")->assertNoContent();
        $this->assertSame(1, $user->annexes()->count());

        $this->actingAs($user, 'sanctum')->deleteJson("/api/annexes/{$annex->id}/join")->assertNoContent();
        $this->actingAs($user, 'sanctum')->deleteJson("/api/annexes/{$annex->id}/join")->assertNoContent();
        $this->assertSame(0, $user->annexes()->count());
    }

    public function test_only_admins_can_create_rename_and_delete_annexes(): void
    {
        $user = User::factory()->create();
        $annex = Annex::factory()->create();

        $this->actingAs($user, 'sanctum')->postJson('/api/annexes', ['name' => 'Sur'])->assertForbidden();
        $this->actingAs($user, 'sanctum')->putJson("/api/annexes/{$annex->id}", ['name' => 'Sur'])->assertForbidden();
        $this->actingAs($user, 'sanctum')->deleteJson("/api/annexes/{$annex->id}")->assertForbidden();

        $admin = User::factory()->admin()->create();
        $this->actingAs($admin, 'sanctum')->postJson('/api/annexes', ['name' => 'Sur'])
            ->assertCreated()->assertJsonPath('data.name', 'Sur');
        $this->actingAs($admin, 'sanctum')->putJson("/api/annexes/{$annex->id}", ['name' => 'Oeste'])
            ->assertOk()->assertJsonPath('data.name', 'Oeste');
    }

    public function test_annex_names_are_unique(): void
    {
        Annex::factory()->create(['name' => 'Centro']);

        $this->actingAs(User::factory()->admin()->create(), 'sanctum')
            ->postJson('/api/annexes', ['name' => 'Centro'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('name');
    }

    public function test_deleting_an_annex_with_setlists_is_rejected(): void
    {
        $annex = Annex::factory()->create();
        Setlist::factory()->create(['annex_id' => $annex->id]);

        $this->actingAs(User::factory()->admin()->create(), 'sanctum')
            ->deleteJson("/api/annexes/{$annex->id}")
            ->assertUnprocessable()
            ->assertJsonPath('message', 'Este anexo tiene setlists; borralos antes.');
        $this->assertDatabaseHas('annexes', ['id' => $annex->id]);
    }

    public function test_deleting_an_empty_annex_removes_memberships(): void
    {
        $admin = User::factory()->admin()->create();
        $annex = Annex::factory()->create();
        $admin->annexes()->attach($annex);

        $this->actingAs($admin, 'sanctum')->deleteJson("/api/annexes/{$annex->id}")->assertNoContent();

        $this->assertDatabaseMissing('annexes', ['id' => $annex->id]);
        $this->assertDatabaseCount('annex_user', 0);
    }
}
