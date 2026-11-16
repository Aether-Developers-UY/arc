<?php

namespace Tests;

use App\Models\Setlist;
use App\Models\User;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    /**
     * A setlist created by [$user], who is also a member of its annex (only
     * members can see a setlist).
     */
    protected function setlistFor(User $user, array $attributes = []): Setlist
    {
        $setlist = Setlist::factory()->create(['created_by' => $user->id, ...$attributes]);
        $user->annexes()->syncWithoutDetaching([$setlist->annex_id]);

        return $setlist;
    }
}
