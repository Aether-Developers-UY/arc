<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ReorderSetlistSongsRequest;
use App\Http\Requests\StoreSetlistSongRequest;
use App\Http\Requests\UpdateSetlistSongRequest;
use App\Models\Setlist;
use App\Models\SetlistSong;
use App\Models\Song;
use Illuminate\Support\Facades\DB;

class SetlistSongController extends Controller
{
    public function store(StoreSetlistSongRequest $request, Setlist $setlist)
    {
        $this->authorize('view', $setlist);
        $song = Song::findOrFail($request->validated('song_id'));
        $nextPosition = $setlist->setlistSongs()->count();

        $setlistSong = $setlist->setlistSongs()->create([
            'song_id' => $song->id,
            'position' => $nextPosition,
            'key' => $request->validated('key') ?? $song->original_key,
        ]);

        return response()->json(['data' => $setlistSong], 201);
    }

    public function update(UpdateSetlistSongRequest $request, Setlist $setlist, SetlistSong $setlistSong)
    {
        $this->authorize('view', $setlist);
        $setlistSong->update(['key' => $request->validated('key')]);

        return response()->json(['data' => $setlistSong]);
    }

    public function destroy(Setlist $setlist, SetlistSong $setlistSong)
    {
        $this->authorize('view', $setlist);
        $setlistSong->delete();

        return response()->noContent();
    }

    public function reorder(ReorderSetlistSongsRequest $request, Setlist $setlist)
    {
        $this->authorize('view', $setlist);
        DB::transaction(function () use ($request) {
            foreach ($request->validated('setlist_song_ids') as $position => $setlistSongId) {
                SetlistSong::where('id', $setlistSongId)->update(['position' => $position]);
            }
        });

        return response()->json(['data' => $setlist->setlistSongs()->get()]);
    }
}
