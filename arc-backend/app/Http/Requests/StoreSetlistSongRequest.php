<?php

namespace App\Http\Requests;

use App\Models\Setlist;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreSetlistSongRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'song_id' => ['required', 'integer', 'exists:songs,id'],
            'key' => ['nullable', 'string', 'max:8'],
            'section' => ['nullable', Rule::in(Setlist::SECTIONS)],
        ];
    }
}
