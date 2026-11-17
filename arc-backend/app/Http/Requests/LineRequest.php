<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class LineRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:120'],
            'key' => ['required', 'string', 'max:8'],
            'songs' => ['required', 'array', 'min:1'],
            'songs.*.song_id' => ['required', 'integer', 'exists:songs,id'],
            'songs.*.key' => ['nullable', 'string', 'max:8'],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required' => 'Poné un nombre a la línea.',
            'key.required' => 'Elegí la tonalidad de la línea.',
            'songs.required' => 'Agregá al menos una canción.',
            'songs.min' => 'Agregá al menos una canción.',
        ];
    }
}
