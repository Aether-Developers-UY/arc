<?php

namespace Tests\Feature;

use App\Models\Annex;
use App\Models\Setlist;
use App\Models\Song;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AnnexModelTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_user_can_belong_to_several_annexes(): void
    {
        $user = User::factory()->create();
        [$centro, $norte, $sur] = Annex::factory()->count(3)->create();
        $user->annexes()->attach([$centro->id, $norte->id]);

        $this->assertSame(2, $user->annexes()->count());
        $this->assertTrue($user->isMemberOf($centro));
        $this->assertTrue($user->isMemberOf($norte->id));
        $this->assertFalse($user->isMemberOf($sur));
    }

    public function test_users_are_standard_by_default_and_admin_state_works(): void
    {
        $user = User::factory()->create()->fresh();

        $this->assertSame('standard', $user->role);
        $this->assertFalse($user->isAdmin());
        $this->assertTrue(User::factory()->admin()->create()->isAdmin());
    }

    public function test_deleting_a_user_keeps_their_songs_and_setlists(): void
    {
        $user = User::factory()->create();
        $song = Song::factory()->create(['created_by' => $user->id]);
        $setlist = Setlist::factory()->create(['created_by' => $user->id]);

        $user->delete();

        $this->assertDatabaseHas('songs', ['id' => $song->id, 'created_by' => null]);
        $this->assertDatabaseHas('setlists', ['id' => $setlist->id, 'created_by' => null]);
    }
}
