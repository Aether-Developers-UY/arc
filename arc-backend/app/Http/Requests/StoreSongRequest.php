<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreSongRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:255'],
            'artist' => ['nullable', 'string', 'max:255'],
            'original_key' => ['required', 'string', 'max:8'],
            'tempo' => ['nullable', 'integer', 'min:20', 'max:300'],
            'time_signature' => ['nullable', 'string', 'max:8'],
            'content' => ['required', 'string'],
            'notes' => ['nullable', 'string'],
        ];
    }
}
