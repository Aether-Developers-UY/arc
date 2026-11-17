<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ReorderSetlistSongsRequest;
use App\Http\Requests\StoreSetlistSongRequest;
use App\Http\Requests\UpdateSetlistSongRequest;
use App\Models\Line;
use App\Models\Setlist;
use App\Models\SetlistSong;
use App\Models\Song;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SetlistSongController extends Controller
{
    public function store(StoreSetlistSongRequest $request, Setlist $setlist)
    {
        $this->authorize('view', $setlist);
        $song = Song::findOrFail($request->validated('song_id'));

        $setlistSong = DB::transaction(function () use ($request, $setlist, $song) {
            // Past the end, then renumbered: it lands last in its block.
            $setlistSong = $setlist->setlistSongs()->create([
                'song_id' => $song->id,
                'position' => ($setlist->setlistSongs()->max('position') ?? -1) + 1,
                'key' => $request->validated('key') ?? $song->original_key,
                'section' => $request->validated('section'),
            ]);
            $setlist->normalizePositions();

            return $setlistSong->fresh();
        });

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
        DB::transaction(function () use ($setlist, $setlistSong) {
            $setlistSong->delete();
            $setlist->normalizePositions();
        });

        return response()->noContent();
    }

    /** Songs only move within their own block. */
    public function reorder(ReorderSetlistSongsRequest $request, Setlist $setlist)
    {
        $this->authorize('view', $setlist);
        DB::transaction(function () use ($request, $setlist) {
            foreach ($request->validated('setlist_song_ids') as $position => $setlistSongId) {
                SetlistSong::where('id', $setlistSongId)->update(['position' => $position]);
            }
            $setlist->normalizePositions();
        });

        return response()->json(['data' => $setlist->setlistSongs()->get()]);
    }

    /**
     * Fills the line block with a copy of the line's songs and keys,
     * replacing what was there. A copy, so editing the line later leaves
     * this service as it was planned.
     */
    public function useLine(Request $request, Setlist $setlist)
    {
        $this->authorize('view', $setlist);
        $line = Line::with('lineSongs')->findOrFail(
            $request->validate(['line_id' => ['required', 'integer', 'exists:lines,id']])['line_id'],
        );

        DB::transaction(function () use ($setlist, $line) {
            $setlist->setlistSongs()->where('section', 'linea')->delete();
            $start = ($setlist->setlistSongs()->max('position') ?? -1) + 1;
            foreach ($line->lineSongs as $i => $lineSong) {
                $setlist->setlistSongs()->create([
                    'song_id' => $lineSong->song_id,
                    'position' => $start + $i,
                    'key' => $lineSong->key,
                    'section' => 'linea',
                    'line_id' => $line->id,
                ]);
            }
            $setlist->normalizePositions();
        });

        return response()->json(['data' => $setlist->fresh()->load(Setlist::SONGS_WITH)]);
    }
}
