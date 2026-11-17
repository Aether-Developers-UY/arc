<?php

namespace App\Http\Requests;

use App\Models\User;
use Illuminate\Validation\Rule;

/** The rules for a username, shared by creating and editing a user. */
trait UsernameRules
{
    protected function prepareForValidation(): void
    {
        if (is_string($this->input('username'))) {
            $this->merge(['username' => User::normalizeUsername($this->input('username'))]);
        }
    }

    /** One word, 3 to 30 characters: letters, numbers, ".", "_" or "-". */
    protected function usernameRules(?User $ignore = null): array
    {
        return [
            'required',
            'string',
            'min:3',
            'max:30',
            'regex:/^[a-z0-9._-]+$/',
            Rule::unique('users', 'username')->ignore($ignore),
        ];
    }

    public function messages(): array
    {
        return [
            'username.unique' => 'Ese nombre de usuario ya existe.',
            'username.regex' => 'Usá una sola palabra con letras, números, punto, guion o guion bajo.',
            'username.min' => 'El nombre de usuario necesita al menos 3 caracteres.',
        ];
    }
}
