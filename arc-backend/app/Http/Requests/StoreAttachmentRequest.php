<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreAttachmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'type' => ['required', 'in:audio,pdf,other'],
            'file' => [
                'required',
                'file',
                'max:20480', // 20MB in kilobytes
                'mimetypes:audio/mpeg,audio/mp4,audio/wav,audio/x-wav,application/pdf,application/octet-stream',
            ],
        ];
    }

    public function messages(): array
    {
        return [
            'file.max' => 'El archivo supera el tamaño máximo permitido.',
            'file.mimetypes' => 'El tipo de archivo no está permitido.',
        ];
    }
}
