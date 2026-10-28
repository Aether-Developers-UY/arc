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
            ->when($request->query('search'), function ($query, $search) {
                $query->where(function ($q) use ($search) {
                    $q->where('title', 'like', "%{$search}%")
                        ->orWhere('artist', 'like', "%{$search}%");
                });
            })
            ->orderBy('title')
            ->get();

        return response()->json(['data' => $songs]);
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
