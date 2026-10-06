const joi = require("joi");

const createTaskSchema = joi.object({
  title: joi.string().required(),
  review: joi.string().required(),
  dueDate: joi.date().required(),
  clientId: joi.number().integer().required(),
  workers: joi.array().items(Joi.number().integer()).optional()
});

module.exports = {
  createTaskSchema,
};