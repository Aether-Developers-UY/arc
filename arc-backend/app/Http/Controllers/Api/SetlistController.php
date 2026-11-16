<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreSetlistRequest;
use App\Http\Requests\UpdateSetlistRequest;
use App\Models\Setlist;
use Illuminate\Http\Request;

class SetlistController extends Controller
{
    public function index(Request $request)
    {
        // Songs come along so the list can preview them (blocks, Inicio).
        $annexIds = $request->user()->annexes()->pluck('annexes.id');
        if ($request->filled('annex_id')) {
            $annexId = (int) $request->input('annex_id');
            abort_unless($annexIds->contains($annexId), 404);
            $annexIds = collect([$annexId]);
        }

        $setlists = Setlist::query()
            ->whereIn('annex_id', $annexIds)
            ->with('setlistSongs.song')
            ->orderBy('service_date')
            ->get();

        return response()->json(['data' => $setlists]);
    }

    public function store(StoreSetlistRequest $request)
    {
        $setlist = Setlist::create([
            ...$request->safe()->only(['service_date', 'name']),
            'annex_id' => $request->annexId(),
            'created_by' => $request->user()->id,
        ]);

        return response()->json(['data' => $setlist], 201);
    }

    public function show(Setlist $setlist)
    {
        $this->authorize('view', $setlist);
        $setlist->load('setlistSongs.song');

        return response()->json(['data' => $setlist]);
    }

    public function update(UpdateSetlistRequest $request, Setlist $setlist)
    {
        $this->authorize('view', $setlist);
        $setlist->update($request->validated());

        return response()->json(['data' => $setlist]);
    }

    public function destroy(Setlist $setlist)
    {
        $this->authorize('view', $setlist);
        $setlist->delete();

        return response()->noContent();
    }
}
