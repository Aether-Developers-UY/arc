<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreSongRequest;
use App\Http\Requests\UpdateSongRequest;
use App\Models\Song;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class SongController extends Controller
{
    public function index(Request $request)
    {
        $songs = Song::query()
            ->with('attachments')
            ->when(trim((string) $request->query('search')), function ($query, $search) {
                $like = '%'.self::escapeLike($search).'%';
                $lyrics = '%'.self::escapeLike(Song::normalizeForSearch($search)).'%';
                $query->where(function ($q) use ($like, $lyrics) {
                    $q->whereRaw("title like ? escape '!'", [$like])
                        ->orWhereRaw("artist like ? escape '!'", [$like])
                        ->orWhereRaw("lyrics like ? escape '!'", [$lyrics]);
                });
            })
            ->orderBy('title')
            ->get();

        return response()->json(['data' => $songs]);
    }

    /** Makes % and _ in what was typed match themselves. */
    private static function escapeLike(string $value): string
    {
        return str_replace(['!', '%', '_'], ['!!', '!%', '!_'], $value);
    }

    public function store(StoreSongRequest $request)
    {
        $song = Song::create([
            ...$request->validated(),
            'created_by' => $request->user()->id,
        ]);

        return response()->json(['data' => $song], 201);
    }

    public function show(Song $song)
    {
        return response()->json(['data' => $song->load('attachments')]);
    }

    public function update(UpdateSongRequest $request, Song $song)
    {
        $song->update($request->validated());

        return response()->json(['data' => $song]);
    }

    public function destroy(Song $song)
    {
        // The database cascades the attachment rows, but not the stored
        // files: remove those first so they don't pile up orphaned.
        Storage::disk('public')->delete($song->attachments()->pluck('file_path')->all());

        $song->delete();

        return response()->noContent();
    }
}
