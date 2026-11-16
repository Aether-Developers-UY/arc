<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class AnnexRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => [
                'required',
                'string',
                'max:100',
                Rule::unique('annexes', 'name')->ignore($this->route('annex')),
            ],
        ];
    }

    public function messages(): array
    {
        return ['name.unique' => 'Ya existe un anexo con ese nombre.'];
    }
}
