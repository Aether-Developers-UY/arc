<?php

namespace App\Policies;

use App\Models\Setlist;
use App\Models\User;
use Illuminate\Auth\Access\Response;

class SetlistPolicy
{
    /**
     * Only members of the setlist's annex can see or touch it. Everyone
     * else gets a 404, so another annex's setlists don't even show up as
     * existing.
     */
    public function view(User $user, Setlist $setlist): Response
    {
        return $user->isMemberOf($setlist->annex_id)
            ? Response::allow()
            : Response::denyAsNotFound();
    }
}
