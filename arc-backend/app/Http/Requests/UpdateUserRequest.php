<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateUserRequest extends FormRequest
{
    use UsernameRules;

    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'username' => ['sometimes', ...$this->usernameRules($this->route('user'))],
            'role' => ['sometimes', 'required', Rule::in(['standard', 'admin'])],
            'password' => ['sometimes', 'required', 'string', 'min:8'],
        ];
    }
}
