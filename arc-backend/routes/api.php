<?php

use App\Http\Controllers\Api\AttachmentController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\SetlistController;
use App\Http\Controllers\Api\SetlistSongController;
use App\Http\Controllers\Api\SongController;
use Illuminate\Support\Facades\Route;

Route::get('/ping', fn () => response()->json(['status' => 'ok']));

Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:6,1');

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::apiResource('songs', SongController::class);
    Route::post('/songs/{song}/attachments', [AttachmentController::class, 'store']);
    Route::get('/attachments/{attachment}/download', [AttachmentController::class, 'download']);
    Route::delete('/attachments/{attachment}', [AttachmentController::class, 'destroy']);
    Route::apiResource('setlists', SetlistController::class);
    Route::post('/setlists/{setlist}/songs', [SetlistSongController::class, 'store']);
    Route::put('/setlists/{setlist}/songs/{setlistSong}', [SetlistSongController::class, 'update']);
    Route::delete('/setlists/{setlist}/songs/{setlistSong}', [SetlistSongController::class, 'destroy']);
    Route::put('/setlists/{setlist}/reorder', [SetlistSongController::class, 'reorder']);
});
