<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreAttachmentRequest;
use App\Models\Attachment;
use App\Models\Song;
use Illuminate\Support\Facades\Storage;

class AttachmentController extends Controller
{
    public function store(StoreAttachmentRequest $request, Song $song)
    {
        $file = $request->file('file');
        $path = $file->store('attachments', 'public');

        $attachment = $song->attachments()->create([
            'type' => $request->validated('type'),
            'original_name' => $file->getClientOriginalName(),
            'file_path' => $path,
            'mime_type' => $file->getClientMimeType(),
            'size' => $file->getSize(),
        ]);

        return response()->json(['data' => $attachment], 201);
    }

    public function download(Attachment $attachment)
    {
        return Storage::disk('public')->download(
            $attachment->file_path,
            $attachment->original_name
        );
    }

    public function destroy(Attachment $attachment)
    {
        Storage::disk('public')->delete($attachment->file_path);
        $attachment->delete();

        return response()->noContent();
    }
}
