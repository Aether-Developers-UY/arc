<?php

namespace App\Http\Requests;

use App\Models\SetlistSong;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class ReorderSetlistSongsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'setlist_song_ids' => ['required', 'array'],
            'setlist_song_ids.*' => ['integer'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator) {
            $setlist = $this->route('setlist');
            $given = collect($this->input('setlist_song_ids', []))->sort()->values();
            $actual = SetlistSong::where('setlist_id', $setlist->id)
                ->pluck('id')
                ->sort()
                ->values();

            if ($given->all() !== $actual->all()) {
                $validator->errors()->add(
                    'setlist_song_ids',
                    'La lista debe contener exactamente las canciones actuales del setlist.'
                );
            }
        });
    }
}
