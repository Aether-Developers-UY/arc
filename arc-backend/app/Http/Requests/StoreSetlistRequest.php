<?php

namespace App\Http\Requests;

use Closure;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class StoreSetlistRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'service_date' => ['required', 'date'],
            'name' => ['nullable', 'string', 'max:255'],
            'annex_id' => [
                'nullable',
                'integer',
                function (string $attribute, mixed $value, Closure $fail) {
                    if (! $this->user()->isMemberOf((int) $value)) {
                        $fail('No sos parte de ese anexo.');
                    }
                },
            ],
        ];
    }

    /**
     * Older app builds don't send an annex: fall back to the user's first
     * one (by id), and reject the request if they have none.
     */
    public function after(): array
    {
        return [
            function (Validator $validator) {
                if ($this->filled('annex_id')) {
                    return;
                }
                if ($this->firstAnnexId() === null) {
                    $validator->errors()->add('annex_id', 'Unite a un anexo para crear setlists.');
                }
            },
        ];
    }

    public function annexId(): int
    {
        return $this->filled('annex_id') ? (int) $this->input('annex_id') : $this->firstAnnexId();
    }

    private function firstAnnexId(): ?int
    {
        return $this->user()->annexes()->orderBy('annexes.id')->value('annexes.id');
    }
}
