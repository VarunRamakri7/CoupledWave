

#ifdef DEBUG

const int kErrorBinding = 10;
layout (std430, binding = kErrorBinding) restrict buffer ERROR 
{
	ivec4 mError;
	vec4 mErrorData;
};

void ClearError()
{
	mError = ivec4(0);
}

void SetError(int error)
{
	mError.x = error;
}

void SetError(ivec4 error)
{
	mError = error;
}
void SetErrorData(vec4 error_data)
{
	mErrorData = error_data;
}

#else
void ClearError(){}
void SetError(int error){}
void SetError(ivec4 error){}
void SetErrorData(vec4 error_data){}
#endif
